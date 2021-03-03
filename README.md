
> 注意： 建议先切换到root用来在操作。Ubuntu下默认没有给root用户设置密码。需要先`sudo passwd root` 设置root用户的密码。然后在`su` 切换到root

## 为什么编译内核

好奇！
如果需要学习内核，那么首先需要会编译内核，了解内核如何启动根文件系统。这样你才能在修改linux内核代码之后，完成验证的过程。

## 前提准备

- Linux kernel 源代码：[https://www.kernel.org/](https://www.kernel.org/) [https://mirrors.edge.kernel.org/pub/linux/kernel/](https://mirrors.edge.kernel.org/pub/linux/kernel/)
- busybox [https://busybox.net/downloads/](https://busybox.net/downloads/)
- qemu Ubuntu请直接`sudo apt install qemu`


## 我的文件组织方式

```
    $HOME/kernel #在当前用户用kernel作为操作的文件夹
        kernel/busybox/busybox-1.30.0 #放置busybox
        kernel/busybox/busybox-1.30.0/pack_image_ext4.sh # 打包文件系统为镜像的脚本
        kernel/linux-4.9.229 # Linux内核源代码
        startMiniLinux.sh # 启动qemu的脚本
```

## 编译内核

1. 指定硬件体系架构。`export ARCH=x86` 我在本例中使用的是x86。如果你要编译arm的内核，则指定ARCH=arm (非arm机器需要安装交叉编译器)。
2. 配置board config,此处配置为 x86_64_defconfig `make  x86_64_defconfig`
3. 配置内核 `make menuconfig` （配置系统，各种配置都在这里）

**配置内核支持ramdisk驱动**
```
General setup  --->
       ----> [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support
    Device Drivers  --->
       [*] Block devices  --->
               <*>   RAM block device support
               (65536) Default RAM disk size (kbytes)
```

**编译内核**

```shell
make
```
**编译成功后的内核位于：arch/x86/boot/bzImage** （编译结束时候终端会显示内核路径的，根据你的情况看）

## 编译busybox来制作`根文件系统`镜像

**使用busybox是为了制作一个很小但可以被内核启动的文件系统。**

本地使用的busybox-1.30.0

```shell
# 解压
tar xvf busybox-1.30.0.tar.bz2
```

```shell
# 配置
make menuconfig
```

建议设置为静态编译。
```
# 按空格选中或者不选，左右键选择底边选项，Exit(返回上一层，放心最后会问你是否保存修改的)
Busybox Settings --->
        Build Options --->
            [*] Build static binary (no shared libs)
```

```shell
#编译 建议所有的操作都是用root用户
make 
# 安装
make install
```
### 组织根文件系统

**编译安装完成后busybox会在当前目录下的_install文件夹下**。
**进入_install目录，补充一些必要的文件或目录(形成Linux的目录结构)。**
相关的shell命令如下：（没有# 开头的行都是文件里面要填写的内容）

```shell
# 下面的所有操作建议使用root用户，或者在命令的前面加sudo
# mkdir etc dev mnt
# mkdir -p proc sys tmp mnt
# mkdir -p etc/init.d/

# 配置启动的挂载
# vim etc/fstab
proc        /proc           proc         defaults        0        0
tmpfs       /tmp            tmpfs    　　defaults        0        0
sysfs       /sys            sysfs        defaults        0        0
# 初始化相关
# vim etc/init.d/rcS
echo -e "Welcome to tinyLinux"
/bin/mount -a
echo -e "Remounting the root filesystem"
mount  -o  remount,rw  /
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s
# chmod 755 etc/init.d/rcS

#  初始化相关
# vim etc/inittab
::sysinit:/etc/init.d/rcS
::respawn:-/bin/sh
::askfirst:-/bin/sh
::cttlaltdel:/bin/umount -a -r
# chmod 755 etc/inittab

# 创建设备
# cd dev
# mknod console c 5 1
# mknod null c 1 3
# mknod tty1 c 4 1 
```

### 封装根文件系统成镜像

> 建议把下面命令写成一个shell脚本。起一个好辩别的名字放在busybox根目录(比如：pack_image_ext4.sh)
> 编程世界中，如果一个操作你需要做3次以上，那么建议你封装为脚本，自动化。（忘了谁说的啦，反正挺有道理）

```shell
#! /bin/bash
rm -rf rootfs.ext4
rm -rf fs
dd if=/dev/zero of=./rootfs.ext4 bs=1M count=32
mkfs.ext4 rootfs.ext4
mkdir fs
mount -o loop rootfs.ext4 ./fs
cp -rf ./_install/* ./fs
umount ./fs
gzip --best -c rootfs.ext4 > rootfs.img.gz 
```
> 参考的文章是制作的ext3，这里修改为ext4
> [关于loop设备的参考](https://my.oschina.net/ruochenchen/blog/149259)

思路：（直接看脚本也知道啥意思）
1. 先制作一个空的镜像文件；
2. 然后把此镜像文件格式化为ext4格式；
3. 然后把此镜像文件挂载，并把根文件系统复制到挂载目录；
4. 卸载该镜像文件。
5. 打成gzip包。

## 使用qemu加载内核和文件系统

>还是建议封装为脚本，我这里封装为`startminiLinux.sh`

```shell
#! /bin/bash
qemu-system-x86_64 \
-kernel ${HOME}/kernel/linux-4.9.229/arch/x86/boot/bzImage \
-initrd ${HOME}/kernel/busybox/busybox-1.30.0/rootfs.img.gz \
-append "root=/dev/ram init=/linuxrc" \
-serial file:output.txt
```
注意这里的 -kernel的路径，我参考文章那里就写错了，导致`VFS: Unable to mount root fs on unknown-block(0,0)`
>请使用普通用户执行，记得用sudo来执行。（因为路径我这里用的是${HOME},切换root用户执行，因为用了${HOME}变量，上面的路径肯定找不到bzImage等文件，所以用普通用户配合sudo来执行此脚本。）

## 参考：

https://www.bilibili.com/video/BV1yk4y1B7Fx/?spm_id_from=333.788.videocard.3 (里面有一些错误，上面的编译内核那里已经修改过了)
