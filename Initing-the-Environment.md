
生信技能树的转录组学习开班了, 第一个任务是[安装软件](http://www.biotrainee.com/forum.php?mod=viewthread&tid=1742#lastpost), 于是我花了一个下午时间和Linux斗智斗勇。

## 系统准备
windows10： Unbuntu on windows10

![微软的良心](http://oex750gzt.bkt.clouddn.com/17-7-18/44267883.jpg)

建议搭配cmder，界面更好看，用的更开心。
![](http://oex750gzt.bkt.clouddn.com/17-7-18/14384827.jpg)

但是直接在cmder里启动ubuntu不能使用方向键，需要做一些修改，即在cmder的setting的startup的command line添加
```
%windir%\system32\bash.exe ~ -cur_console:p:n
```
![](http://oex750gzt.bkt.clouddn.com/17-7-18/64270190.jpg)



## 软件准备（conda）
1.下载miniconda https://conda.io/miniconda.html Linux Python2.7
```
cd src
wget https://repo.continuum.io/miniconda/Miniconda2-latest-Linux-x86_64.sh
bash Miniconda2-latest-Linux-x86_64.sh
```
根据提示，最后会安装到`~/miniconda2`下。
2.添加bioconda channel, 目前还没有国内源
``` bash
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/msys2/
conda config --add channels bioconda
conda config --set show_channel_urls yes
```

3.用conda安装软件sratoolkit,fastqc,hisat2,samtools,htseq-count, 与网络有着密切的关系
查询可供安装的软件, https://bioconda.github.io/recipes.html#recipes
```
conda create -n biostar sra-tools fastqc hisat2 samtools htseq
```

R语言和Rstudio就看下面的讲解。

## 软件准备（编译篇）
我的习惯：
- 家目录下创建src文件夹，用于存放软件包
- 家目录下创建biosoft文件夹，用于安装软件

为了提高下载速度，我们需要替换`/etc/apt/source.list`中默认镜像源。方法参考自[中国科学技术大学开源镜像站](http://mirrors.ustc.edu.cn/help/ubuntu.html)
```
# 备份
cd /etc/apt/
sudo cp source.list source.list.bk
# 替换
sudo sed -i 's/http/https/g' sources.list
sudo sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' sources.list
sudo sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' sources.list
# 更新
sudo apt-get update
sudo apt-get upgrade
```
选择合适的镜像站，让你的速度飞起来

### sratookit
功能： 下载，操作，验证NCBI SRA中二代测序数据
网址：[https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software)
步骤：
```
cd src
wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/2.8.2-1/sratoolkit.2.8.2-1-ubuntu64.tar.gz
tar -zxvf sratoolkit.2.8.2-1-ubuntu64.tar.gz
mv sratoolkit.2.8.2-1-ubuntu64 ~/biosoft
# 加入环境变量
echo 'PATH=$PATH:~/biosoft/sratoolkit.2.8.2-1-ubuntu64/bin' >> ~/.bashrc
# 测试
prefetch -v
# 尝试下载，默认存放在家目录下的ncbi文件夹中
prefetch -c SRR390728
```

阅读官方文章进一步了解：
1. 如何开启ascp加速下载
2. vdb-config更改基本设置

### fastqc
功能： 可视化展示二代测序数据质量
网站：[http://www.bioinformatics.babraham.ac.uk/projects/fastqc/](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
步骤：
```
# 判断系统是否安装java
java -version
# 安装java， 请改成openjdk-9-jdk，下面的是错误演示
sudo apt install  openjdk-9-jre-headless
# 验证
java -version
# openjdk version "9-internal"
# OpenJDK Runtime Environment (build 9-internal+0-2016-04-14-195246.buildd.src)
# OpenJDK 64-Bit Server VM (build 9-internal+0-2016-04-14-195246.buildd.src, mixed mode)
# 安装fastqc
cd src
wget http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.5.zip
unzip fastqc_v0.11.5.zip
mv FastQC/ ~/biosoft/
cd ~/biosoft/FastQC/
chmod 770 fastqc
# 添加环境变量， 我用sed修改
sed -i '/^PATH/s/\(.*\)/\1:~\/biosoft\/FastQC\//' ~/.bashrc
source ~/.bashrc
fastqc -v
# FastQC v0.11.5
```

拓展：
1. 了解fastqc结果中各个图的含义
2. 掌握如何从fastqc的结果中提取数据
3. 学习sed的用法，http://dongweiming.github.io/sed_and_awk/



### samtools
SAM: 存放高通量测序比对结果的标准格式
功能： Reading/writing/editing/indexing/viewing SAM/BAM/CRAM format
网站: [http://samtools.sourceforge.net/](http://samtools.sourceforge.net/)
安装：
```
cd src
#  prerequsite
## system requirement
sudo apt install autoconf libz-dev libbz2-dev liblzma-dev libssl-dev

### zlib2
wget http://zlib.net/zlib-1.2.11.tar.gz
tar -zxvf zlib-1.2.11.tar.gz && cd zlib-1.2.11 && make && sudo make install && cd .. && rm -rf zlib-1.2.11

### bzip2
wget http://bzip.org/1.0.6/bzip2-1.0.6.tar.gz
tar -zxvf bzip2-1.0.6.tar.gz && cd bzip2-1.0.6 && make && sudo make install && cd .. && rm -rf  bzip2-1.0.6

### curses
sudo apt-get install libncurses5-dev

### htslib
git clone https://github.com/samtools/htslib.git
cd htslib
autoreconf

# building samtools
git clone https://github.com/samtools/samtools.git
cd samtools
autoconf -Wno-syntax
./configure
make && make install prefix=$HOME/biosoft/samtools

## add PATH
sed  '/^PATH/s/\(.*\)/\1:~\/biosoft\/samtools\/bin/' .bashrc -i
source ~/.bashrc
samtools --help
```

顺便安装bcftools
```
cd src
git clone https://github.com/samtools/bcftools.git
make && make install prefix=$HOME/biosoft/bcftools
make clean
sed  '/^PATH/s/\(.*\)/\1:~\/biosoft\/bcftools\/bin/' .bashrc -i
source ~/.bashrce
bcftools -h
```

因为用的是github，所以以后更新就用下面命令
```
cd htslib; git pull
cd ../bcftools; git pull
make clean
make
```

吐槽： 编译的时候需要安装好多前置包，真麻烦！


### HISAT2
功能： 将测序结果比对到参考基因组上
网站： [http://ccb.jhu.edu/software/hisat2/index.shtml](http://ccb.jhu.edu/software/hisat2/index.shtml)
安装：
```
cd src
wget ftp://ftp.ccb.jhu.edu/pub/infphilo/hisat2/downloads/hisat2-2.1.0-source.zip
unzip hisat2-2.1.0-source.zip
# 编译hisat2
cd hisat2-2.1.0
make
rm -f *.h *.cpp
cd ../
mv hisat2-2.1.0 ~/biosoft/hisat2
# add to PATH
sed  '/^PATH/s/\(.*\)/\1:~\/biosoft\/hisat2/' ~/.bashrc -i
source ~/.bashrc
# test
hisat2 -h
```

吐槽： 居然没有make install !!!
拓展：
- HISAT2支持`--sra-acc <SRA accession number> `,也就是可以集成SRATOOLS的，但是需要安装额外包，可以看文章自己折腾。

### HTSeq
功能： 根据比对结果统计基因count
```
# prerequsites
sudo apt-get install python-pip
pip install --upgrade pip
sudo apt-get install build-essential python2.7-dev python-numpy python-matplotlib
## 验证， 保证无报错
python -V
## python
python
>>> import numpy
>>> import matplotlib

## install HTSeq
pip install htseq

## 验证
python
>>> import HTSeq

```

教程：
1. http://www-huber.embl.de/users/anders/HTSeq/doc/tour.html#tour

推荐：
1. 推荐安装一个ipython，学习ipython如何使用
2. 将软件包安装到当前用户目录下`pip install --user xxx`

### R
Ubuntu 14.04的自带R版本跟不上时代的变化，然后自己编译的坑有太多，所以先用Linux处理数据，然后在Windows下分析数据。这样就很轻松了。一些需要编译的软件包，还可以用RTools。
R：https://cran.r-project.org/
Rstudio： https://www.rstudio.com/

**二进制版本**： R官方提供了Ubuntu最新版本更新方法,如下
```
# 添加Secure APT
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
# 添加deb到source.list
vi source.list
deb https://mirrors.ustc.edu.cn/CRAN/bin/linux/ubuntu xenial/
deb https://mirrors.ustc.edu.cn/ubuntu/ xenial-backports main restricted universe
# 更新并安装
sudo apt-get update
sudo apt-get install r-base
# (optional)如果要自己编译R
sudo apt-get install r-base-dev
# 测试
which R
/usr/bin/R
```

安装之后建议修改一下R包镜像源，提高下载速度。
```
vi ~/.Rprofile
options("repos" = c(CRAN="https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))
options(BioC_mirror="https://mirrors.tuna.tsinghua.edu.cn/bioconductor")
```


**编译部分**：新手阶段不要轻易尝试，如果你能顺利搞定，你的Linux能力已经过关了

如何处理`./configure`中出现的问题：
- configure: error: No F77 compiler found
```
sudo apt-get install gfortran
```
- configure: error: --with-readline=yes (default) and headers/libs are not available
```
# 其实可以--with-readlines=no, 但是还是把东西装了吧
install libreadline-dev
```
- configure: error: --with-x=yes (default) and X11 headers/libs are not available
```
# 因为是CLI模式，不需要GUI
./configure --with-x=no
```
- configure: error: pcre >= 8.20 library and headers are required
```
sudo apt-get install libpcre3 libpcre3-dev
```

**注**： 上面安装其他软件时用到的包，其实也有一部分是R所需要的，如果出错的话，也是谷歌+必应+百度一个一个解决。

```
./configure --with-x=no --prefix=$HOME/biosoft/R3.4.1
```

最后配置成功后会出现如下结果：
```
R is now configured for x86_64-pc-linux-gnu

  Source directory:          .
  Installation directory:    /usr/local

  C compiler:                gcc  -g -O2
  Fortran 77 compiler:       f95  -g -O2

  Default C++ compiler:      g++   -g -O2
  C++98 compiler:            g++  -g -O2
  C++11 compiler:            g++ -std=gnu++11 -g -O2
  C++14 compiler:            g++ -std=gnu++14 -g -O2
  C++17 compiler:
  Fortran 90/95 compiler:    gfortran -g -O2
  Obj-C compiler:

  Interfaces supported:
  External libraries:        readline, curl
  Additional capabilities:   NLS
  Options enabled:           shared BLAS, R profiling

  Capabilities skipped:      PNG, JPEG, TIFF, cairo, ICU
  Options not enabled:       memory profiling

  Recommended packages:      yes

configure: WARNING: you cannot build info or HTML versions of the R manuals
configure: WARNING: you cannot build PDF versions of the R manuals
configure: WARNING: you cannot build PDF versions of vignettes and help pages
```

这些警告无伤大雅，毕竟CLI看不了PDF。

```
make
```
然后我发现一个错误
```
error: jni.h: No such file or directory
```
原因是之前的`openjdk-9-jre-headless`无头， 不完整，所以需要重新安装一个完整的
```
# 先卸载
sudo apt-get remove openjdk-9-jre-headless
# 后安装最完整java环境
sudo apt-get install openjdk-9-jdk
```

然后重新`make && make install`
我以为自己不会遇到问题了，结果
```
installing doc ...
/usr/bin/install: 无法获取'NEWS.pdf' 的文件状态(stat): 没有那个文件或目录
/usr/bin/install: 无法获取'NEWS.pdf' 的文件状态(stat): 没有那个文件或目录
Makefile:121: recipe for target 'install-sources2' failed
```
MDZZ!本来就没有考虑到x11模块，不能搞pdf，你和我说报错！于是我默默去百度一下，给出的方法是忽略错误
```
make install -i
```
谢天谢地，终于通过了！！！添加环境变量测试一下吧
```
sed '/^PATH/s/\(.*\)/\1:~\/biosoft\/R-3\.4\.1\/bin\//' .bashrc -i
R
> .libPath()
[1] "/home/xzg/biosoft/R-3.4.1/lib/R/library"
# 安装Hadley大神的包压压惊
install.packages("tidyverse")
```
真麻烦！我要去Y叔的小密圈问下，看看他有没有其他更好的方法

![Biobabble](http://upload-images.jianshu.io/upload_images/2013053-d03009dfe58ef6e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## 一点经验
以后在Ubuntu安装软件之前，先保证如下被安装了。
```
## build-essential
sudo apt-get install build-essential
## java
sudo apt install  openjdk-9-jdk

## 各种包
sudo apt install autoconf libz-dev libbz2-dev liblzma-dev libssl-dev

### zlib2
wget http://zlib.net/zlib-1.2.11.tar.gz
tar -zxvf zlib-1.2.11.tar.gz && cd zlib-1.2.11 && make && sudo make install && cd .. && rm -rf zlib-1.2.11

### bzip2
wget http://bzip.org/1.0.6/bzip2-1.0.6.tar.gz
tar -zxvf bzip2-1.0.6.tar.gz && cd bzip2-1.0.6 && make && sudo make install && cd .. && rm -rf  bzip2-1.0.6

### curses
sudo apt-get install libncurses5-dev
```

- R编译需要的Java必须是完全体，所以必须是 openjdk-9-jdk，不然无限报错
- `make -i` 可以忽略系统报错，继续走下去，很多时候一点小错是没有关系的
- 如果`./configure --prefix=/path/to/where`写错了，然后最后安装的地方错了， 不能简单的把软件包挪个位置就行了，至少要把目录内的`R-3.4.1/bin/R`和`R-3.4.1/lib/R/bin/R`的路径进行修改。
- make得要好好学习，有些时候不能`./configure && make && make install prefix=/path/to/where`一套走下来,有点作者可能没有定义install
- 我们遇到的问题基本上无数前人已经填坑了，所以谷歌百度必应总能找到， 如果你想偷懒，那你可以加入我的小密圈，向我提问。


![做到](http://upload-images.jianshu.io/upload_images/2013053-41dc3ed770adc0d9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
