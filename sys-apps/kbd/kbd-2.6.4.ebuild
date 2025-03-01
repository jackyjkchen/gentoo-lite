# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit multiprocessing

if [[ $(ver_cut 3) -lt 90 ]] ; then
	SRC_URI="https://www.kernel.org/pub/linux/utils/kbd/${P}.tar.xz"
	KEYWORDS="amd64"
else
	inherit autotools
	SRC_URI="https://github.com/legionus/kbd/archive/v${PV}.tar.gz -> ${P}.tar.gz"
fi

DESCRIPTION="Keyboard and console utilities"
HOMEPAGE="https://kbd-project.org/"

LICENSE="GPL-2"
SLOT="0"
IUSE="nls selinux pam test"
RESTRICT="!test? ( test )"

# Testsuite's Makefile.am calls missing(!)
# ... but this seems to be consistent with the autoconf docs?
# Needs more investigation: https://www.gnu.org/software/autoconf/manual/autoconf-2.67/html_node/autom4te-Invocation.html
QA_AM_MAINTAINER_MODE=".*--run autom4te --language=autotest.*"

DEPEND="
	app-alternatives/gzip
	pam? (
		!app-misc/vlock
		sys-libs/pam
	)
"
RDEPEND="
	${DEPEND}
	selinux? ( sec-policy/selinux-loadkeys )
"
BDEPEND="
	virtual/pkgconfig
	test? ( dev-libs/check )
"

src_prepare() {
	default

	# Rename conflicting keymaps to have unique names, bug #293228
	# See also https://github.com/legionus/kbd/issues/76.
	pushd "${S}"/data/keymaps/i386 &> /dev/null || die
	mv fgGIod/trf.map fgGIod/trf-fgGIod.map || die
	mv olpc/es.map olpc/es-olpc.map || die
	mv olpc/pt.map olpc/pt-olpc.map || die
	mv qwerty/cz.map qwerty/cz-qwerty.map || die
	popd &> /dev/null || die

	if [[ ${PV} == 9999 ]] || [[ $(ver_cut 3) -ge 90 ]] ; then
		eautoreconf
	fi
}

src_configure() {
	local myeconfargs=(
		--disable-werror

		$(use_enable nls)
		$(use_enable pam vlock)
		$(use_enable test tests)
	)

	econf "${myeconfargs[@]}"
}

src_test() {
	emake -Onone check TESTSUITEFLAGS="--jobs=$(get_makeopts_jobs)"
}

src_install() {
	default

	docinto html
	dodoc docs/doc/*.html

	# USE="test" installs .la files
	find "${ED}" -type f -name "*.la" -delete || die
}
