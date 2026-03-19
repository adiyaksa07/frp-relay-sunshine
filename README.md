# frp-relay-sunshine

This project mainly provides a configuration setup to deploy **FRP (Fast Reverse Proxy)** as a “relay” between Sunshine and Moonlight. This allows you to stream games with low latency over the internet, even if your computer is behind a firewall or NAT.

## Project Overview

Sunshine is an open-source game streaming server that works great with Moonlight, offering excellent performance with low latency and high image quality.

However, if your Sunshine host doesn’t have a public IP address, Moonlight won’t be able to connect. That’s where FRP comes in—to handle NAT traversal. This repository helps you set everything up so you don’t have to deal with the hassle.

## What’s Included

* `frpc.ini`: FRP client configuration file
* `frps.ini`: FRP server configuration file
* `v2_optimize_network.sh`: Network optimization script (optional, helps improve stability by tuning parameters)

## Prerequisites

You’ll need to install the following first:

* Sunshine: [https://github.com/LizardByte/Sunshine](https://github.com/LizardByte/Sunshine)
* FRP: [https://github.com/fatedier/frp](https://github.com/fatedier/frp)

## How to Use

1. **Set up the FRP server (run on a server with a public IP)**

   * Modify `frps.ini` according to your ports and token
   * Start the server:

     ```bash
     ./frps -c frps.ini
     ```

2. **Set up the FRP client (run on the machine running Sunshine)**

   * Edit `frpc.ini` and fill in the correct server address and port
   * Start the client:

     ```bash
     ./frpc -c frpc.ini
     ```

3. **Network optimization (highly recommended)**

   * To make streaming through your VPS smoother and more stable, it’s recommended to run the updated script `v2_optimize_network.sh`. Avoid older versions—this one is more reliable.

     ```bash
     ./v2_optimize_network.sh
     ```

---

Enjoy! The most important thing is having a smooth gaming experience—don’t overcomplicate it.
