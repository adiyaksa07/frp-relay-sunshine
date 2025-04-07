# frp-relay-sunshine

这个项目主要是搞一个配置，用来把 **FRP（Fast Reverse Proxy）** 搭起来，让它能当 Sunshine 和 Moonlight 之间的“中转站”。这样你就能在外网低延迟地串流游戏了，不管你电脑是在防火墙后面还是 NAT 后面，都能直接连。

## 项目介绍

Sunshine 是一个开源的游戏串流服务端，可以跟 Moonlight 配合使用，效果贼棒，低延迟高画质。

但是，如果你家里的 Sunshine 主机不是公网 IP，那 Moonlight 根本连不上，这时候就得用 FRP 来穿透。这个 repo 就是帮你配置好这些东西，让你省点事儿。

## 项目里有什么

- `frpc.ini`：FRP 客户端配置文件
- `frps.ini`：FRP 服务端配置文件
- `v2_optimize_network.sh`：网络优化脚本（可选，能调一些参数，让网络更稳）

## 准备工作

先得装好这两个东西：

- Sunshine：[https://github.com/LizardByte/Sunshine](https://github.com/LizardByte/Sunshine)
- FRP：[https://github.com/fatedier/frp](https://github.com/fatedier/frp)

## 怎么用？

1. **配置 FRP 服务端（在有公网 IP 的服务器上运行）**
   - 根据你实际的端口和 token 修改 `frps.ini`
   - 启动服务端：

     ```bash
     ./frps -c frps.ini
     ```

2. **配置 FRP 客户端（在运行 Sunshine 的机器上运行）**
   - 改好 `frpc.ini`，填对服务器地址和端口
   - 启动客户端：

     ```bash
     ./frpc -c frpc.ini
     ```

3. **网络优化（推荐一定要跑）**
   - 为了让 VPS 串流更稳更顺，建议跑一下这个新版的脚本：`v2_optimize_network.sh`。老版本就别用了，这个更靠谱。

     ```bash
     ./v2_optimize_network.sh
     ```

---

欢迎使用，能玩得爽最重要，别太折腾。
