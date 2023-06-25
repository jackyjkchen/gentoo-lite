# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="FreeBASIC compiler"
SRC_URI="https://github.com/freebasic/fbc/releases/download/1.10.0/FreeBASIC-${PV}-source-bootstrap.tar.xz"

LICENSE="GPL-2+"
KEYWORDS="amd64 x86 arm arm64"
IUSE="X gpm opengl "
SLOT="0"

S="${WORKDIR}/FreeBASIC-${PV}-source-bootstrap"

BDEPEND="dev-libs/libffi
	gpm? ( sys-libs/gpm )
	X? ( x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXpm
	x11-libs/libXrandr
	x11-base/xorg-proto )
	opengl? ( media-libs/libglvnd[X] )"
RDEPEND="sys-libs/ncurses"
DEPEND="${RDEPEND}"

pkg_pretend() {
	if use opengl ; then
		if ! use X ; then
			eerror "use opengl need use X"
		fi
	fi
}

src_prepare() {
	default
	eapply "${FILESDIR}"/fbc-bootstrap.patch
	if ! use gpm ; then
		DISABLE_GPM="-DDISABLE_GPM"
	fi
	if ! use X ; then
		DISABLE_X11="-DDISABLE_X11"
	fi
	if ! use opengl ; then
		DISABLE_OPENGL="-DDISABLE_OPENGL"
	fi
	CFLAGS="${CFLAGS} ${DISABLE_GPM} ${DISABLE_X11} ${DISABLE_OPENGL}"
	einfo "CFLAGS=${CFLAGS}"
}

src_compile() {
	if [[ ${ARCH} == "amd64" || ${ARCH} == "arm64" ]] ; then
		export C_INCLUDE_PATH=/usr/lib64/libffi/include
	else
		export C_INCLUDE_PATH=/usr/lib/libffi/include
	fi
	emake DESTDIR="${D}" BUILD_PREFIX=/usr/bin/ prefix=/usr bootstrap-minimal V=1
	emake DESTDIR="${D}" BUILD_PREFIX=/usr/bin/ prefix=/usr FBC=bin/fbc V=1
}

src_install() {
	emake DESTDIR="${D}" BUILD_PREFIX=/usr/bin/ prefix=/usr FBC=bin/fbc install
}
