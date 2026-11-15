# Ghostty terminfo

Ghostty 1.4.0公式macOSアプリ同梱のterminfoを `infocmp -x xterm-ghostty` でテキスト化した。
再生成時は、アプリのterminfoを `infocmp -A <appのterminfoディレクトリ> -x xterm-ghostty` で指定し、先頭のローカルパスを含むコメントを除く。
Ubuntuでは `tic -x` でユーザー領域にコンパイルする。本体の導入やビルドは不要。

- 配布元: https://github.com/ghostty-org/ghostty/releases/tag/v1.4.0
- 手順: https://ghostty.org/docs/help/terminfo
- ライセンス: MIT（同梱のLICENSE）
