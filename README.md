# 卫星导航定位原理实验项目

![MATLAB](https://img.shields.io/badge/MATLAB-R2016b+-blue.svg) ![Language](https://img.shields.io/badge/Language-中文-red.svg) ![License](https://img.shields.io/badge/License-Educational-green.svg) ![Status](https://img.shields.io/badge/Status-Complete-success.svg)

卫星导航定位原理课程实验代码，包含卫星坐标计算和单点定位算法实现。

## 项目简介

本项目使用 MATLAB 实现了 GNSS 导航定位的核心算法：
- 广播星历卫星坐标计算
- 单点定位（SPP）解算
- 迭代最小二乘定位

## 目录结构

```
.
├── 实验一/
│   ├── 卫星坐标计算程序.m     # 星历解算程序
│   ├── brdc0010.25p          # 广播星历文件
│   └── data.m                # 实验数据
│
└── 实验二/
    ├── SPP.m                 # 单点定位算法
    ├── SPP_Best.m            # 优化版定位算法
    ├── data.txt              # 观测数据
    └── c.txt                 # 辅助数据
```

## 实验内容

### 实验一：卫星坐标计算

基于广播星历计算卫星在 WGS-84 坐标系下的三维坐标：
1. 读取 RINEX 格式星历文件
2. 根据开普勒轨道参数计算卫星位置
3. 考虑地球自转改正

### 实验二：单点定位

实现基于伪距观测的单点定位算法：
1. 读取伪距观测数据
2. 迭代最小二乘解算接收机位置
3. 计算钟差和定位精度

## 使用方法

### 环境要求
- MATLAB R2016b 或更高版本

### 运行示例

```matlab
% 卫星坐标计算
cd 实验一
卫星坐标计算程序

% 单点定位
cd 实验二
SPP          % 基础版
SPP_Best     % 优化版
```

## 技术说明

**广播星历解算**  
利用开普勒轨道参数和摄动改正项计算卫星瞬时位置。

**单点定位算法**  
基于伪距观测量的最小二乘迭代解算，获得接收机位置和钟差。

**坐标系统**  
采用 WGS-84 地心地固坐标系（ECEF）进行计算。

## 许可

本项目仅用于教学和学习目的。

