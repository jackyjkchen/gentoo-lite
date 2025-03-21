# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# See https://sourceware.org/gdb/wiki/DistroAdvice for general packaging
# tips & notes.

GUILE_COMPAT=( 2-2 3-0 )
PYTHON_COMPAT=( python3_{10..13} )
inherit flag-o-matic guile-single linux-info python-single-r1 strip-linguas toolchain-funcs

export CTARGET=${CTARGET:-${CHOST}}

if [[ ${CTARGET} == ${CHOST} ]] ; then
	if [[ ${CATEGORY} == cross-* ]] ; then
		export CTARGET=${CATEGORY#cross-}
	fi
fi

is_cross() { [[ ${CHOST} != ${CTARGET} ]] ; }

# Normal upstream release
SRC_URI="
	mirror://gnu/gdb/${P}.tar.xz
	https://sourceware.org/pub/gdb/releases/${P}.tar.xz
"

REGULAR_RELEASE=1

PATCH_DEV=""
PATCH_VER=""
DESCRIPTION="GNU debugger"
HOMEPAGE="https://sourceware.org/gdb/"
SRC_URI="
	${SRC_URI}
	${PATCH_DEV:+https://dev.gentoo.org/~${PATCH_DEV}/distfiles/${CATEGORY}/${PN}/${P}-patches-${PATCH_VER}.tar.xz}
	${PATCH_VER:+mirror://gentoo/${P}-patches-${PATCH_VER}.tar.xz}
"

LICENSE="GPL-3+ LGPL-2.1+"
SLOT="0"
IUSE="cet debuginfod guile lzma multitarget nls +python rocm +server sim source-highlight test vanilla xml xxhash zstd"
if [[ -n ${REGULAR_RELEASE} ]] ; then
	KEYWORDS="amd64"
fi
REQUIRED_USE="
	guile? ( ${GUILE_REQUIRED_USE} )
	python? ( ${PYTHON_REQUIRED_USE} )
	rocm? ( multitarget )
"
RESTRICT="!test? ( test )"

RDEPEND="
	dev-libs/mpfr:=
	dev-libs/gmp:=
	>=sys-libs/ncurses-5.2-r2:=
	>=sys-libs/readline-7:=
	sys-libs/zlib
	debuginfod? (
		dev-libs/elfutils[debuginfod(-)]
	)
	lzma? ( app-arch/xz-utils )
	python? ( ${PYTHON_DEPS} )
	guile? ( ${GUILE_DEPS} )
	xml? ( dev-libs/expat )
	rocm? ( <dev-libs/rocdbgapi-6.3 )
	source-highlight? (
		dev-util/source-highlight
	)
	xxhash? (
		dev-libs/xxhash
	)
	zstd? ( app-arch/zstd:= )
"
DEPEND="${RDEPEND}"
BDEPEND="
	app-arch/xz-utils
	sys-apps/texinfo
	app-alternatives/yacc
	nls? ( sys-devel/gettext )
	source-highlight? ( virtual/pkgconfig )
	test? ( dev-util/dejagnu )
"

QA_CONFIG_IMPL_DECL_SKIP=(
	MIN # gnulib FP (bug #898688)
)

QA_PREBUILT="${PREFIX}/share/gdb/guile/*"

PATCHES=(
	"${FILESDIR}"/${PN}-8.3.1-verbose-build.patch
)

PREFIX=${CUSTOM_PREFIX:-${EPREFIX}/usr}

pkg_setup() {
	local CONFIG_CHECK

	if kernel_is -ge 6.11.3 ; then
		# https://forums.gentoo.org/viewtopic-p-8846891.html
		#
		# Either CONFIG_PROC_MEM_ALWAYS_FORCE or CONFIG_PROC_MEM_FORCE_PTRACE
		# should be okay, but not CONFIG_PROC_MEM_NO_FORCE.
		CONFIG_CHECK+="
			~!PROC_MEM_NO_FORCE
		"
	fi

	linux-info_pkg_setup

	use guile && guile-single_pkg_setup
	use python && python-single-r1_pkg_setup
}

src_prepare() {
	default

	use guile && guile_bump_sources

	strip-linguas -u bfd/po opcodes/po

	# Avoid using ancient termcap from host on Prefix systems
	sed -i -e 's/termcap tinfow/tinfow/g' \
		gdb/configure{.ac,} || die
	if [[ ${CHOST} == *-solaris* ]] ; then
		# code relies on C++11, so make sure we get that selected
		# due to Python 3.11 pymacro.h doing stuff to work around
		# versioning mess based on the C version, while we're compiling
		# C++ here, so we need to make it clear we're doing C++11/C11
		# because Solaris system headers act on these
		sed -i -e 's/-x c++/-std=c++11/' gdb/Makefile.in || die
	fi
}

gdb_branding() {
	printf "Gentoo ${PV} "

	if ! use vanilla && [[ -n ${PATCH_VER} ]] ; then
		printf "p${PATCH_VER}"
	else
		printf "vanilla"
	fi

	[[ -n ${EGIT_COMMIT} ]] && printf " ${EGIT_COMMIT}"
}

src_configure() {
	strip-unsupported-flags

	# See https://www.gnu.org/software/make/manual/html_node/Parallel-Output.html
	# Avoid really confusing logs from subconfigure spam, makes logs far
	# more legible.
	MAKEOPTS="--output-sync=line ${MAKEOPTS}"

	local myconf=(
		# portage's econf() does not detect presence of --d-d-t
		# because it greps only top-level ./configure. But not
		# libiberty's or gdb's configure.
		--disable-dependency-tracking
		--disable-silent-rules

		--disable-werror
		# Disable modules that are in a combined binutils/gdb tree. bug #490566
		--disable-{binutils,etc,gas,gold,gprof,gprofng,ld}

		$(use_with debuginfod)

		$(use_enable test unit-tests)

		# Allow user to opt into CET for host libraries.
		# Ideally we would like automagic-or-disabled here.
		# But the check does not quite work on i686: bug #760926.
		$(use_enable cet)

		# Helps when cross-compiling. Not to be confused with --with-sysroot.
		--with-build-sysroot="${ESYSROOT}"
	)

	# gdbserver only works for native targets (CHOST==CTARGET).
	# it also doesn't support all targets, so rather than duplicate
	# the target list (which changes between versions), use the
	# "auto" value when things are turned on, which is triggered
	# whenever no --enable or --disable is given
	if is_cross || use !server ; then
		myconf+=( --disable-gdbserver )
	fi

	myconf+=(
		--enable-64-bit-bfd
		--disable-install-libbfd
		--disable-install-libiberty
		--enable-obsolete
		# This only disables building in the readline subdir.
		# For gdb itself, it'll use the system version.
		--disable-readline
		--with-system-readline
		# This only disables building in the zlib subdir.
		# For gdb itself, it'll use the system version.
		--without-zlib
		--with-system-zlib
		--with-separate-debug-dir=${PREFIX}/lib/debug
		--with-amd-dbgapi=$(usex rocm)
		$(use_with xml expat)
		$(use_with lzma)
		$(use_enable nls)
		$(use_enable sim)
		$(use_enable source-highlight)
		$(use multitarget && echo --enable-targets=all)
		$(use_with python python "${EPYTHON}")
		$(use_with xxhash)
		$(use_with guile)
		$(use_with zstd)

		# Find libraries using the toolchain sysroot rather than the configured
		# prefix. Needed when cross-compiling.
		#
		# Check which libraries to apply this to with:
		# "${S}"/gdb/configure --help | grep without-lib | sort
		--without-lib{babeltrace,expat,gmp,iconv,ipt,lzma,mpfr,xxhash}-prefix
	)
	[[ -n ${CUSTOM_PREFIX} ]] && myconf+=(
		--with-static-standard-libraries
	)

	# source-highlight is detected with pkg-config: bug #716558
	export ac_cv_path_pkg_config_prog_path="$(tc-getPKG_CONFIG)"

	export CC_FOR_BUILD="$(tc-getBUILD_CC)"

	# ensure proper compiler is detected for Clang builds: bug #831202
	export GCC_FOR_TARGET="${CC_FOR_TARGET:-$(tc-getCC)}"

	einfo "${S}"/configure --prefix=${PREFIX} "${myconf[@]}"
	"${S}"/configure --prefix=${PREFIX} "${myconf[@]}"
}

src_test() {
	# Run the unittests (nabbed invocation from Fedora's spec file) at least
	emake -k -C gdb run GDBFLAGS='-batch -ex "maintenance selftest"'

	# Too many failures
	# In fact, gdb's test suite needs some work to get passing.
	# See e.g. https://sourceware.org/gdb/wiki/TestingGDB.
	# As of 11.2, on amd64: "# of unexpected failures    8600"
	# Also, ia64 kernel crashes when gdb testsuite is running.
	#emake -k check
}

src_install() {
	emake DESTDIR="${D}" install

	find "${ED}"/${PREFIX} -name libiberty.a -delete || die

	# Delete translations that conflict with binutils-libs. bug #528088
	# Note: Should figure out how to store these in an internal gdb dir.
	if use nls ; then
		find "${ED}" \
			-regextype posix-extended -regex '.*/(bfd|opcodes)[.]g?mo$' \
			-delete || die
	fi

	# Don't install docs when building a cross-gdb
	if [[ ${CTARGET} != ${CHOST} ]] ; then
		rm -rf "${ED}"/${PREFIX}/share/{doc,info,locale} || die
		local f
		for f in "${ED}"/${PREFIX}/share/man/*/* ; do
			if [[ ${f##*/} != ${CTARGET}-* ]] ; then
				mv "${f}" "${f%/*}/${CTARGET}-${f##*/}" || die
			fi
		done
		return 0
	fi

	# Install it by hand for now:
	# https://sourceware.org/ml/gdb-patches/2011-12/msg00915.html
	# Only install if it exists due to the twisted behavior (see
	# notes in src_configure above).
	[[ -e gdbserver/gdbreplay ]] && dobin gdbserver/gdbreplay

	docinto gdb
	dodoc gdb/CONTRIBUTE gdb/README gdb/MAINTAINERS \
		gdb/NEWS gdb/PROBLEMS
	docinto sim
	dodoc sim/{MAINTAINERS,README-HACKING}

	if use server ; then
		docinto gdbserver
		dodoc gdbserver/README
	fi

	# Remove shared info pages
	rm -f "${ED}"/${PREFIX}/share/info/{annotate,bfd,configure,ctf-spec,standards}.info*

	use guile && guile_unstrip_ccache

	if use python ; then
		python_optimize "${ED}"/${PREFIX}/share/gdb/python/gdb
	fi

	if [[ -n ${CUSTOM_PREFIX} ]]
	then
		mkdir ${ED}/${PREFIX}/scripts && cp -L /usr/lib64/{libreadline.so.8,libz.so.1,libtinfow.so.6,libncursesw.so.6,libpython3.11.so.1.0,liblzma.so.5,libmpfr.so.6,libgmp.so.10} ${ED}/${PREFIX}/scripts/ && mv -v ${ED}/${PREFIX}/bin/gdb ${ED}/${PREFIX}/bin/gdb1 && mv -v ${ED}/${PREFIX}/bin/gdb-add-index ${ED}/${PREFIX}/bin/gdb-add-index1 && mv -v ${ED}/${PREFIX}/bin/gcore ${ED}/${PREFIX}/bin/gcore1 && cp -avx ${FILESDIR}/python ${FILESDIR}/init ${ED}/${PREFIX}/scripts/ || die
		cat <<-_EOF_ > ${ED}/${PREFIX}/bin/gdb || die
#!/bin/sh
export LD_LIBRARY_PATH=${PREFIX}/scripts
export gdb_package_path=${PREFIX}/scripts
PYTHONHOME=${PREFIX}/python3.11.7 ${PREFIX}/bin/gdb1 -x \${gdb_package_path}/init "\$@"
_EOF_
		cat <<-_EOF_ > ${ED}/${PREFIX}/bin/gdb-add-index || die
#!/bin/sh
export LD_LIBRARY_PATH=${PREFIX}/scripts
${PREFIX}/bin/gdb-add-index1 "\$@"
_EOF_
		cat <<-_EOF_ > ${ED}/${PREFIX}/bin/gcore || die
#!/bin/sh
export LD_LIBRARY_PATH=${PREFIX}/scripts
${PREFIX}/bin/gcore1 "\$@"
_EOF_
		chmod +x ${ED}/${PREFIX}/bin/*
	fi
}

pkg_postinst() {
	# Portage doesn't unmerge files in /etc
	rm -vf "${EROOT}"/etc/skel/.gdbinit

	if use prefix && [[ ${CHOST} == *-darwin* ]] ; then
		ewarn "gdb is unable to get a mach task port when installed by Prefix"
		ewarn "Portage, unprivileged.  To make gdb fully functional you'll"
		ewarn "have to perform the following steps:"
		ewarn "  % sudo chgrp procmod ${PREFIX}/bin/gdb"
		ewarn "  % sudo chmod g+s ${PREFIX}/bin/gdb"
	fi
}
