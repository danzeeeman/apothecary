#!/usr/bin/env bash
#
# libxml2
# XML parser
# http://xmlsoft.org/index.html
#
# uses an automake build system

FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" "emscripten" )


# define the version by sha
VER=2.9.4


# download the source code and unpack it into LIB_NAME
function download() {
    wget ftp://xmlsoft.org/libxml2/libxml2-${VER}.tar.gz
    tar xzf libxml2-${VER}.tar.gz
    mv libxml2-${VER} libxml2
    rm libxml2-${VER}.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    if [ "$TYPE" == "android" ]; then
        cp $FORMULA_DIR/glob.h .
    fi

    if [ "$TYPE" == "vs" ]; then
        cp $FORMULA_DIR/vs2015/*.h include/libxml/
        cp -r $FORMULA_DIR/vs2015/* win32/VC10/
    fi
}

# executed inside the lib src dir
function build() {
    if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		cd win32/VC10
		if [ $ARCH == 32 ] ; then
			vs-build libxml2.vcxproj Build "Release|Win32"
		else
			vs-build libcurl.vcxproj Build "Release|x64"
		fi

	elif [ "$TYPE" == "android" ]; then
        source ../../android_configure.sh $ABI
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
	    if [ "$ARCH" == "armv7" ]; then
            HOST=armv7a-linux-android
        elif [ "$ARCH" == "x86" ]; then
            HOST=x86-linux-android
        fi
        ./configure --host=$HOST --without-lzma --without-zlib --disable-shared --enable-static --with-sysroot=$SYSROOT --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
	    make -j${PARALLEL_MAKE}
	elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"

        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
	    make -j${PARALLEL_MAKE}


	elif [ "$TYPE" == "emscripten" ]; then
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
        emconfigure ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
	    make -j${PARALLEL_MAKE}
	elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"

        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
	    make -j${PARALLEL_MAKE}

	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="i386 x86_64 armv7 arm64" #armv7s
        fi
		for IOS_ARCH in ${IOS_ARCHS}; do
            echo
            echo
            echo "Compiling for $IOS_ARCH"
    	    source ../../ios_configure.sh $TYPE $IOS_ARCH
            local PREFIX=$PWD/build/$TYPE/$IOS_ARCH
            ./configure --prefix=$PREFIX  --host=$HOST --target=$HOST  --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
            make clean
            make -j${PARALLEL_MAKE}
            make install
        done

        cp -r build/$TYPE/arm64/* build/$TYPE/

        if [ "$TYPE" == "ios" ]; then
            lipo -create build/$TYPE/i386/lib/libxml2.a \
                         build/$TYPE/x86_64/lib/libxml2.a \
                         build/$TYPE/armv7/lib/libxml2.a \
                         build/$TYPE/arm64/lib/libxml2.a \
                        -output build/$TYPE/lib/libxml2.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create build/$TYPE/x86_64/lib/libxml2.a \
                         build/$TYPE/arm64/lib/libxml2.a \
                        -output build/$TYPE/lib/libxml2.a
        fi
    else
        echo "building other for $TYPE"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib
            export CFLAGS=-I$SYSROOT/usr/include
        fi

        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        ./buildconf
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
		./configure --with-ssl=$OPENSSL_DIR --enable-static --disable-shared
        make clean
	    make -j${PARALLEL_MAKE}
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/libxml

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE
    cp -Rv include/libxml/* $1/include/libxml/

	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v "win32/VC10/Release/libxml2.lib" $1/lib/$TYPE/Win32/
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v "win32/VC10/Release/libxml2.lib" $1/lib/$TYPE/x64/
		fi
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# copy lib
		cp -Rv .libs/libxml2.a $1/lib/$TYPE/xml2.a
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		# copy lib
		cp -Rv .libs/libxml2.a $1/lib/$TYPE/$ABI/libxml2.a
	elif [ "$TYPE" == "emscripten" ] ; then
	    mkdir -p $1/lib/$TYPE
		# copy lib
		cp -Rv .libs/libxml2.a $1/lib/$TYPE/libxml2.a
	fi

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v Copyright $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
	else
		make clean
	fi
}
