config|kernel|m=16|m=32|m=64   (net us per layer)
old|gdn:core|78.9|117.0|193.9
cb1|gdn:core|79.0|116.4|194.1
cb2|gdn:core|51.7|77.8|135.6
cb4|gdn:core|49.3|77.5|135.2
tb2|gdn:core|51.3|77.8|135.7
tb8|gdn:core|52.0|77.4|135.2
tb16|gdn:core|51.8|77.6|135.0
old|gdn:gemv-ab|40.8|58.5|90.9
cb1|gdn:gemv-ab|45.9|50.8|92.4
cb2|gdn:gemv-ab|46.5|51.0|92.7
cb4|gdn:gemv-ab|46.8|51.1|92.3
tb2|gdn:gemv-ab|35.1|58.1|85.7
tb8|gdn:gemv-ab|78.1|76.7|87.3
tb16|gdn:gemv-ab|140.9|137.9|137.2
old|gdn:conv|23.5|38.4|63.0
cb1|gdn:conv|15.5|18.1|28.3
cb2|gdn:conv|15.9|18.5|28.5
cb4|gdn:conv|15.9|18.3|28.1
tb2|gdn:conv|16.0|23.2|37.7
tb8|gdn:conv|15.8|17.6|23.6
tb16|gdn:conv|18.4|18.7|22.3

config|GDN sum m=16 (ms/pass)|m=32|m=64
old|8.59|12.30|19.03
cb1|8.43|10.87|17.47
cb2|7.20|9.06|14.70
cb4|7.10|9.04|14.64
tb2|6.61|9.65|14.77
tb8|8.72|10.22|14.17
tb16|11.83|13.29|16.47
