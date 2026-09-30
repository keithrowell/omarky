# 0003 Pin iA Writer Quattro S to its Regular style

The installed `iAWriterQuattroS-Bold.ttf` declares weight 80 (regular), the same as the Regular
face (`fc-query -f '%{weight}'`). Asked for "iA Writer Quattro S" at normal weight, Qt picks the
Bold file, so every paragraph rendered bold.

Every prose text item sets `font.styleName: "Regular"`. Rich-text `<b>`, `<i>` and `<b><i>`
still resolve to the real Bold, Italic and Bold Italic faces (checked in a probe render).
