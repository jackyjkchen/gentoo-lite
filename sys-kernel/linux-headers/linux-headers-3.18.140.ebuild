# Copyright 2021-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION=""
HOMEPAGE=""
SRC_URI="https://mirrors.ustc.edu.cn/kernel.org/linux/kernel/v3.x/linux-${PV}.tar.xz"

LICENSE=""
KEYWORDS="amd64"
SLOT="0"

DEPEND=""
RDEPEND="${DEPEND}"

unset ARCH

S=${WORKDIR}/linux-${PV}

src_compile() {
	emake mrproper || die
	emake headers_check || die
}

src_install() {
	emake INSTALL_HDR_PATH="${ED}"/usr headers_install || die
	find "${ED}"/usr -name '..install.cmd' -delete || die
}
