# MIT License

# Copyright (c) 2020 Huiyun Wu

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#!/bin/bash
echo "进入编译ffmpeg脚本"

export NDK=/mnt/c/developer/Android/android-ndk-r20b
#5.0
export API_LEVEL=21
export PLATFORM=$NDK/platforms/android-$API_LEVEL/arch-arm
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export SYSROOT=$NDK/sysroot
export ASM_INCLUDE=$SYSROOT/usr/include/arm-linux-androideabi
export CPU=armv7-a
export PREFIX=android/$CPU

echo "开始编译ffmpeg"
CFLAG="-I$ASM_INCLUDE -I$SYSROOT/usr/include -isysroot $SYSROOT -fPIC -DANDROID -D__ANDROID_API__=$API_LEVEL -mfpu=neon -mfloat-abi=softfp "
EXTRA_PARMAS="--enable-asm \
    --enable-neon \
    --enable-jni \
    --enable-mediacodec"

#输出路径
./configure \
--prefix=$PREFIX \
--target-os=android \
--cross-prefix=$TOOLCHAIN/bin/arm-linux-androideabi- \
--arch=arm \
--cpu=$CPU  \
--sysroot=$PLATFORM \
--extra-cflags="$CFLAG" \
--cc=$TOOLCHAIN/bin/armv7a-linux-androideabi21-clang \
--nm=$TOOLCHAIN/bin/arm-linux-androideabi-nm \
--ld=$TOOLCHAIN/bin/arm-linux-androideabi-ld \
--disable-shared \
--enable-runtime-cpudetect \
--enable-gpl \
--enable-small \
--enable-cross-compile \
--disable-debug \
--enable-static \
--disable-doc \
--disable-ffmpeg \
--disable-ffplay \
--disable-ffprobe \
--disable-postproc \
--disable-avdevice \
--disable-symver \
--disable-stripping \
$EXTRA_PARMAS

# 由于mac上的sed命令和linux下的sed的参数有差异，所以mac下需要使用下面的参数
# file_path="''"
# linux上使用
file_path=""

fix_definitions=(
    "HAVE_CBRT"
    "HAVE_CBRTF"
    "HAVE_COPYSIGN"
    "HAVE_ERF"
    "HAVE_ISFINITE"
    "HAVE_HYPOT"
    "HAVE_RINT"
    "HAVE_LRINT"
    "HAVE_LRINTF"
    "HAVE_ROUND"
    "HAVE_ROUNDF"
    "HAVE_TRUNC"
    "HAVE_TRUNCF"
    "HAVE_ISNAN"
    "HAVE_LOCALTIME_R"
    "HAVE_GMTIME_R"
    "HAVE_INET_ATON"
)

sed -i $file_path "/#define getenv(x) NULL/d" config.h

for str in ${fix_definitions[@]}; do
    eval "sed -i $file_path 's/$str 0/$str 1/g' config.h"
done

# 清除compat下的.o主要针对stdatomic.o
find compat -name "*.o" | xargs rm -f
make clean
make -j8
make install

# 将几个静态库链接为一个动态库
$TOOLCHAIN/bin/arm-linux-androideabi-ld \
-rpath-link=$PLATFORM/usr/lib \
-L$PLATFORM/usr/lib \
-L$PREFIX/lib \
-soname libffmpeg.so -shared -nostdlib -Bsymbolic --whole-archive --no-undefined -o \
$PREFIX/libffmpeg.so \
    libavutil/libavutil.a \
    libavcodec/libavcodec.a \
    libavfilter/libavfilter.a \
    libswresample/libswresample.a \
    libavformat/libavformat.a \
    libswscale/libswscale.a \
    -lc -lm -lz -ldl -llog --dynamic-linker=/system/bin/linker \
    $TOOLCHAIN/lib/gcc/arm-linux-androideabi/4.9.x/armv7-a/libgcc_real.a \

# strip
$TOOLCHAIN/bin/arm-linux-androideabi-strip $PREFIX/libffmpeg.so
