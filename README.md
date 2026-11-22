# TIT-AL00 (Huawei Enjoy 5 / MT6735) — 4G 数据修复包

> 适用于：华为畅享5 **TIT-AL00**，LineageOS 14.1（`lineage_primel`），MT6735，中国电信 SIM。
> 效果：修复「基带版本未知」「SIM 未插入」「4G 无法上网」，恢复移动数据。
> 不刷机：全部通过 Magisk 模块 + 运行时脚本实现，可完整回滚。

---

## 一、症状

- 设置 → 关于手机 → **基带版本显示「未知」**
- 插卡后提示 **SIM 未插入 / 仅紧急呼叫**
- 状态栏**信号格空心**，旁边有「无 SIM 卡」图标
- **4G 上不了网**（即使显示有信号）
- 换过多个 ROM（含官方 EMUI）症状相同

---

## 二、根因（四个问题叠加，缺一不可）

| # | 问题 | 证据 |
|---|------|------|
| 1 | 内核加载的 `modem_1_lwg_1.img` 是 **TIT-L01 签名**，与 TIT-AL00 不匹配 → modem assert / 看门狗重启 | `/sys/kernel/ccci/boot` 出现异常、`md1:3/2/0` 前反复重启、基带 unknown |
| 2 | 框架 `ApnContext.isReady()` 恒为 `false`（其判断的是 `mDataEnabled` 字段，该字段从未置位）→ DCT 永远不拨号，APN 列表 `mAllApnSettings=null` | `dumpsys activity service com.android.phone` 里 `default:[state=IDLE,enabled=false]` |
| 3 | 所有 APN 类型同时 ready 时，框架会并发建立 5 条 PDN（default/mms/supl/hipri/ia），而设备只有 3 个 ccmni 接口 → `addInterface ccmni2` 失败 → 正常连接也被拆掉 | `E/ConnectivityService: Exception adding interface: '400 addInterface' failed` |
| 4 | modem 数据通路卡死：`AT+CGDATA="M-CCMNI",<cid>,<iface>` 返回 `+CME ERROR: 4356 / 4109 / 3853`，必须重置 modem 才能解开 | radio log 中 `[bindPdnToIntf] CID2 fail to bind interface0` |
| 5 | `SubscriptionController.isSubInfoReady()` 恒为 `false`（`sSlotIdxToSubId` 为空）→ `ActiveSubInfoList=null` → SystemUI 认为没有卡 | `dumpsys isub` 输出 `[getActiveSubInfoList] Sub Controller not ready` |

---

## 三、修复组件

```
modules/
  modem_al00/                 Magisk 模块：modem 固件覆盖
    module.prop
    system/etc/firmware/modem_1_lwg_1.img   ← 安装时从设备自身复制
  fwpatch/                    Magisk 模块：telephony-common.jar 补丁
    module.prop
    system/framework/telephony-common.jar   ← 已打好补丁
scripts/
  fixdata.sh                  数据断开时的一键恢复（重置 modem）
  99datapath.sh               可选：开机自动执行 fixdata.sh
  99rilfix.sh                 可选：开机重启 rild
install.sh                    安装脚本（设备上以 root 运行）
uninstall.sh                  完整回滚
PROMPT.md                     给 AI 助手（DSH）的复现提示词
```

### fwpatch 补丁内容（`telephony-common.jar`）

| 类 / 方法 | 改动 | 作用 |
|---|---|---|
| `ApnContext.isEnabled()` | 恒返回 `true` | 让 APN 上下文可用 |
| `ApnContext.isReady()` | 仅 `getApnType()=="default"` 时返回 `true` | **只允许 default 一条 PDN**，避免 ccmni 接口耗尽 |
| `DcTracker.isDataAllowed()` | 恒返回 `true` | 跳过 PS 限制/未附着判断，允许拨号 |
| `DcTracker.handleMessage` | 删掉 `EVENT_RECORDS_LOADED` 的 subId 校验（`if-eqz v17, :cond_44` → `nop`） | 让 APN 列表能被创建 |
| `DcTracker` 的 `:sswitch_66`（`EVENT_DATA_CONNECTION_ATTACHED`） | 插入 `onRecordsLoadedOrSubIdChanged()` 调用 | 附着时强制建 APN 列表并拨号 |
| `SubscriptionController.isSubInfoReady()` | 恒返回 `true` | 让 `ActiveSubInfoList` 能返回订阅 |
| `SubscriptionController.getActiveSubscriptionInfoList()` | 查询条件 `sim_id>=0` → `1=1` | 槽位为 -1 的订阅也能返回 |

---

## 四、安装

### 前置条件

- 已安装 **Magisk**（能 `su`）
- 建议事先备份：`dd if=/dev/block/by-name/nvram of=/sdcard/nvram.img`（可选）
- 手机已解锁、可 ADB

### 步骤

1. 把整个 `TIT-AL00-DataFix` 目录推到手机：
   ```sh
   adb push TIT-AL00-DataFix /sdcard/
   ```
2. 以 root 运行安装脚本：
   ```sh
   adb shell su -c "sh /sdcard/TIT-AL00-DataFix/install.sh"
   ```
3. 重启：
   ```sh
   adb reboot
   ```
4. 开机后如果数据没起来（`dumpsys connectivity` 里 `Active default network: none`），执行一次恢复脚本：
   ```sh
   adb shell su -c "sh /data/local/tmp/fixdata.sh"
   ```
   它会：等 SIM READY → `stop/start ccci_mdinit` 重置 modem → 重启 rild → 等网络注册。约 1~2 分钟。

### 可选：开机自动恢复

```sh
adb shell su -c "sh /sdcard/TIT-AL00-DataFix/install.sh --with-boot-hook"
```

> ⚠️ 注意：部分机器上开机自动重置 modem 会打断 SIM 识别（表现为 SIM 变成 ABSENT）。
> 如果出现这种情况，删掉 `/data/adb/service.d/99datapath.sh` 后重启，改为手动执行 `fixdata.sh`。

### SIM 卡槽

- 本机测试中，SIM 插在 **SIM1** 时订阅槽位可正常映射；插 SIM2 时 `simSlotIndex` 恒为 -1，状态栏显示无卡。
- 安装后如仍显示无卡，可执行：
  ```sh
  adb shell su -c "content update --uri content://telephony/siminfo --bind sim_id:i:0 --where \"_id=1\""
  adb shell su -c "pkill -f com.android.phone"
  ```

---

## 五、已知限制

- **VoLTE / 语音通话：无法修复。**
  - 该机型 modem 不把 IMS PDN 交给 AP（`AT+CGDATA="M-CCMNI",0,*` 返回 `+CME ERROR`），AP 侧没有任何到 P-CSCF 的网络路径（`ping6` 到 `240e:67:...` 返回 `Network is unreachable`）；
  - ROM 内没有厂商 IMS 服务（`com.android.ims` 等），只有 `ims-common.jar` 框架接口；
  - 即使打开 modem 的 IMS 栈（`AT+EIMS=1` 成功），`AT+CIREG?` 仍为 `2,0,0`（未注册）。
  - 结论：语音只能停留在「仅紧急呼叫」。
- 信号弱（RSRP ≤ -110 dBm）时会掉网、数据不稳定，这属于覆盖问题。
- 状态栏图标跟随「语音是否在服务」，因此即使数据正常，信号格也可能显示为空心。

---

## 六、回滚

```sh
adb shell su -c "sh /sdcard/TIT-AL00-DataFix/uninstall.sh"
adb reboot
```

会删除 `modem_al00`、`fwpatch` 两个模块和所有脚本，恢复到安装前状态（基带会重新变回「未知」）。

---

## 七、致谢与免责

- 本包只修改 `/data/adb/modules`（Magisk overlay）与运行时脚本，**不写入任何分区**。
- `telephony-common.jar` 为原 ROM 文件的反编译 → 修改 → 重打包版本，仅作兼容性修复。
- 操作有风险（Magisk 模块损坏可能导致无法开机），请自行备份并承担后果。
