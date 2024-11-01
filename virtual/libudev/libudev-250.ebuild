# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit multilib-build

DESCRIPTION="Virtual for libudev providers"

SLOT="0/1"
KEYWORDS="amd64"
IUSE=""

RDEPEND="
	sys-fs/eudev[${MULTILIB_USEDEP}]
"
