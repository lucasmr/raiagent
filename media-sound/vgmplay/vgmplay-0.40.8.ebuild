# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit readme.gentoo-r1

DESCRIPTION="Video game music (VGM) file command-line player"
HOMEPAGE="http://vgmrips.net/forum/viewtopic.php?t=112"

# VGMPlay licensing can only be referred to as "extreme." Frankly, the authors
# themselves do not appear to particularly care about licensing or even know
# which licenses apply and when to VGMPlay. The "VGMPlay/licenses/List.txt" file
# purports to be the canonical list of all licenses associated with third-party
# VGMPlay components but nonetheless lists four components for which the license
# is literally unknown:
#
#     Ootake - ?
#     in_vgm - ?
#     MEKA - ?
#     in_wsr - ?
#
# "in_vgm" is the Windows-specific analogue of VGMPlay as a WinAmp plugin and is
# physically contained in the same repository as VGMPlay. Yet its license is
# listed as unknown. Likewise, VGMPlay itself appears to remain unlicensed.
#
# I've never encountered a licensing scenario this painfully disfunctional. If
# even the principal developers of VGMPlay cannot be bothered to either license
# their software *OR* attribute third-party software embedded in their software,
# we certainly cannot be expected to do so. We instead note that, since numerous
# VGMPlay components are GPL 2-licensed, the infectious virality of the GPL
# requires extending that license to VGMPlay itself. Ergo, GPL 2.
LICENSE="GPL-2"
SLOT="0"

IUSE="alsa ao debug opl pulseaudio"
REQUIRED_USE=""

DEPEND="
	sys-libs/zlib
	virtual/libc
	ao? ( media-libs/libao )
"

# VGMPlay indirectly supports ALSA and PulseAudio via OSS runtime emulation in
# the high-level "vgm-player" script. Something is better than nothing.
#
# Note that, although the "pulseaudio' package provides an "oss" USE flag, this
# flag has been deprecated; since this package now unconditionally installs
# "padsp", the PulseAudio OSS wrapper, merely installing "pulseaudio" suffices.
RDEPEND="${DEPEND}
	alsa? ( media-libs/alsa-oss )
	pulseaudio? ( media-sound/pulseaudio )
"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3

	EGIT_REPO_URI="https://github.com/vgmrips/vgmplay"
	KEYWORDS=""
else
	SRC_URI="https://github.com/vgmrips/vgmplay/archive/${PV}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

src_prepare() {
	default

	# Remove the bundled "zlib" directory.
	rm -r VGMPlay/zlib || die '"rm" failed.'

	# Patch the makefile as follows:
	#
	# * Strip hardcoded ${CFLAGS}.
	# * Prevent options from being forcefully enabled.
	sed -e '/CFLAGS := -O3/s~ -O3~~' \
	    -e '/^DISABLE_HWOPL_SUPPORT = 1$/d' \
	    -e '/^USE_LIBAO = 1$/d' \
		-i VGMPlay/Makefile || die '"sed" failed.'
}

src_compile() {
	# List of all options to be passed to VGMPlay's makefile, globalized to
	# allow reuse in the src_install() phase.
	declare -ga VGMPLAY_MAKE_OPTIONS

	# Options to be unconditionally enabled.
	VGMPLAY_MAKE_OPTIONS=( PREFIX="${EROOT}"usr DESTDIR="${D}" )

	# Append all options to be enabled. Option values are ignored such that:
	#
	# * All passed options are considered to be enabled (regardless of value).
	# * All unpassed options are considered to be disabled.
	use ao    && VGMPLAY_MAKE_OPTIONS+=( USE_LIBAO=1 )
	use debug && VGMPLAY_MAKE_OPTIONS+=( DEBUG=1 )
	use opl   || VGMPLAY_MAKE_OPTIONS+=( DISABLE_HWOPL_SUPPORT=1 )

	# VGMPlay only provides a GNU "Makefile"; notably, no autotools-based
	# "configure" script is provided.
	emake --directory=VGMPlay "${VGMPLAY_MAKE_OPTIONS[@]}"
}

src_install() {
	# Absolute path of the system-wide VGMPlay directory.
	VGMPLAY_DIR="${EPREFIX}/usr/share/${PN}"

	# Absolute path of the system-wide VGMPlay configuration file.
	VGMPLAY_CFG_FILE="${EPREFIX}/etc/vgmplay.ini"

	# Create all directories assumed to exist by this makefile.
	exeinto usr/bin

	# Install all VGMPlay commands (e.g., "vgm-player") and manpages.
	emake --directory=VGMPlay play_install "${VGMPLAY_MAKE_OPTIONS[@]}"

	# Link this configuration file from its default non-standard path into a
	# more standard directory.
	dosym "${VGMPLAY_DIR}/vgmplay.ini" "${VGMPLAY_CFG_FILE}"

	# Install all remaining documentation.
	dodoc VGMPlay/*.txt

	# Contents of the "/usr/share/doc/${P}/README.gentoo" file to be installed.
	DOC_CONTENTS="
	VGMPlay supports audio files of filetype \"vgm\" and \"vgz\"
	(gzip-compressed \"vgm\") and \"m3u\" playlists of these files, available
	for effectively all sequenced video game music from the online archive at:
	\\n
	\\n\\thttp://vgmrips.net
	\\n
	\\nTo enable support for files ripped from devices containing OPL4 sound chips
	(e.g., MSX), manually download and copy the \"yrw801.rom\" file into the
	system-wide \"${VGMPLAY_DIR}\" directory:
	\\n
	\\n\\tsudo mv yrw801.rom ${VGMPLAY_DIR}/
	\\n
	\\nTo play supported files, run the \"vgm-player\" wrapper:
	\\n
	\\n\\t# See the \"vgmplay\" manpage for key bindings.
	\\n\\tvgm-player bubbleman.vgz
	\\n
	\\nTo convert supported files to another format, pipe the \"vgm2pcm\"
	command into a suitable audio encoder:
	\\n
	\\n\\t# Convert VGZ to MP3 via \"lame\".
	\\n\\tvgm2pcm bubbleman.vgz - | lame -r - -
	\\n
	\\nVGMPlay is configurable via the system-wide \"${VGMPLAY_CFG_FILE}\"
	file."

	# Install this document.
	readme.gentoo_create_doc
}

pkg_postinst() {
	# Print the "README.gentoo" file installed above on first installation.
	readme.gentoo_print_elog
}
