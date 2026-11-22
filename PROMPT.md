# 给 AI 助手（DSH）的提示词

下面这段可以直接粘贴给 DeepSeek Harness（或任何能操作 ADB 的 AI 助手），让它帮你把本修复包装到手机上。

---

## 提示词（复制以下全部内容）

```
我有一台华为畅享5（TIT-AL00，MT6735，LineageOS 14.1），问题：
- 关于手机里基带版本显示"未知"
- 插卡提示未插入/仅紧急呼叫
- 4G 无法上网

我已经把修复包放在电脑的 D:\TIT-AL00-DataFix 目录（或手机 /sdcard/TIT-AL00-DataFix）。

请你按下面的步骤帮我安装并验证，每步都要实际执行 ADB 命令、看到输出再继续，不要跳过验证：

1. 确认手机已连接、已 root（magisk）：
   adb devices
   adb shell su -c id

2. 把整个修复包推到手机：
   adb push D:\TIT-AL00-DataFix /sdcard/

3. 运行安装脚本：
   adb shell su -c "sh /sdcard/TIT-AL00-DataFix/install.sh"

4. 重启：
   adb reboot
   等 2-3 分钟（首次开机会有 dex2oat 编译，耐心等），然后检查：
   adb shell getprop sys.boot_completed
   adb shell getprop gsm.sim.state          # 期望 READY
   adb shell getprop gsm.operator.numeric   # 期望 46011
   adb shell dumpsys connectivity | grep "Active default network"   # 期望有数字

5. 如果 Active default network 是 none（数据没起来），执行恢复脚本：
   adb shell su -c "sh /data/local/tmp/fixdata.sh"
   等 1-2 分钟后重新检查第 4 步。

6. 如果状态栏仍显示"无 SIM 卡"，执行：
   adb shell su -c "content update --uri content://telephony/siminfo --bind sim_id:i:0 --where \"_id=1\""
   adb shell su -c "pkill -f com.android.phone"
   等 30 秒后检查：
   adb shell dumpsys isub | grep -A1 ActiveSubInfoList   # 期望有记录、simSlotIndex=0

7. 最后确认数据真的能上网，用 TCP 不要用 ping（运营商可能封 ICMP）：
   adb shell "printf 'GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n' | nc -w 8 www.baidu.com 80"
   期望看到 HTTP/1.0 200 OK 或 30x。

注意事项：
- 手机必须已装 Magisk 并有 root 权限；没有 root 这套方案用不了。
- 不要刷任何分区，本方案只写 /data/adb/modules 和运行时脚本。
- 如果开机后 SIM 变成 ABSENT，删掉 /data/adb/service.d/99datapath.sh 再重启（开机自动重置 modem 可能打断 SIM 识别）。
- 语音/VoLTE 修不了，这是该机型的硬件/固件限制，不要在这上面浪费时间。
- 遇到问题先看 README.md 的"已知限制"和"回滚"章节。
```

---

## 给维护者的说明

如果你要自己复现补丁（而不是直接用本仓库的 `telephony-common.jar`），流程是：

1. 从设备取出 `/system/framework/telephony-common.jar`
2. 用 `baksmali` 反编译 `classes.dex`
3. 按 README「三、修复组件」表格中的 7 处修改 smali
4. 用 `smali` 重新打包成 dex，替换 jar 内的 `classes.dex`
5. 放入 Magisk 模块 `system/framework/telephony-common.jar`
6. 重启（首次开机会 dex2oat 较久）

工具：
- `baksmali-2.5.2.jar` / `smali-2.5.2.jar`（Java 8+ 可运行）
- Magisk 20+

> 补丁依赖具体 ROM 的 `telephony-common.jar`，**不同 ROM 不能直接套用**，必须按自己的 jar 重新打补丁。
