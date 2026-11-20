        add (1|M0)               r6.0<1>:q     r4.0<0;1,0>:q     r37.1<0;1,0>:q
        send.ugm (1|M0)          r35      r84  null:0  0x0            0x0220E580           {$1} // wr:1+0, rd:2; load.ugm.d32x32t.a64
        sync.nop                             null                             {$0.src}
        send.ugm (1|M0)          r101     r84  null:0  0x80000            0x0210D580           {$11} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x80]
        send.ugm (1|M0)          r97      r2  null:0  0x0            0x0240F580           {I@2,$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r126     r84  null:0  0xC0000            0x0220E580           {$6} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0xC0]
        send.ugm (1|M0)          r92      r84  null:0  0x140000            0x0210D580           {$14} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x140]
        sync.nop                             null                             {Compacted,$5.src}
        send.ugm (1|M0)          r111     r6  null:0  0x0            0x0240F580           {I@1,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        shr (16|M0)              r7.0<1>:ud    r120.0<1;1,0>:ud  0x18:uw              {Compacted,$4.dst}
        shl (16|M0)              r8.0<1>:d     r121.0<1;1,0>:d   8:w               {Compacted}
        mov (32|M0)              r10.0<1>:f    r120.0<1;1,0>:f                  {Compacted}
        add (1|M0)               r3.0<1>:q     r2.0<0;1,0>:q     r37.1<0;1,0>:q   {Compacted}
        shr (16|M0)              r9.0<1>:ud    r121.0<1;1,0>:ud  0x10:uw              {Compacted}
        shl (16|M0)              r12.0<1>:d    r83.0<1;1,0>:d    16:w               {Compacted,$5.dst}
        or (16|M0)               r11.0<1>:d    r8.0<1;1,0>:d     r7.0<1;1,0>:d    {Compacted,A@1}
        send.ugm (1|M0)          r115     r3  null:0  0x0            0x0240F580           {I@4,$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        shr (16|M0)              r15.0<1>:ud   r83.0<1;1,0>:ud   0x8:uw              {Compacted}
        add (1|M0)               r2.0<1>:q     r3.0<0;1,0>:q     r37.1<0;1,0>:q   {Compacted,$15.src}
        or (16|M0)               r14.0<1>:d    r12.0<1;1,0>:d    r9.0<1;1,0>:d    {Compacted,I@4}
        and (32|M0)              r3.0<1>:w     r10.0<2;1,0>:w    4095:w               {@4,$4.src}
        shl (32|M0)              r10.0<1>:d    r10.0<1;1,0>:d    4:w               {Compacted}
        send.ugm (1|M0)          r93      r4  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        and (32|M0)              r13.0<1>:w    r14.0<2;1,0>:w    4095:w               {I@3}
        mov (32|M0)              r17.0<1>:d    r3.0<1;1,0>:uw                   {I@3}
        add (1|M0)               r4.0<1>:q     r6.0<0;1,0>:q     r37.1<0;1,0>:q   {Compacted,$5.src}
        sync.nop                             null                             {Compacted,I@1}
(W)     mov (1|M0)               r6.0<1>:f     0xFFF0000:f                               {$2.src}
        shl (32|M0)              r14.0<1>:ud   r14.0<1;1,0>:ud   0x4:uw
        mov (32|M0)              r7.0<1>:d     r13.0<1;1,0>:uw
        bfn.0xEA (32|M0)         r19.0<1>:ud   r17.0<1;0>:ud     r10.0<1;0>:ud     r6.0<0>:ud       {F@1} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        and (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0xFFF0000:ud
        bfn.0xEA (32|M0)         r21.0<1>:ud   r7.0<1;0>:ud      r14.0<1;0>:ud     r6.0<0>:ud       {I@3} // s0|s1&s2
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x2:uw              {I@3}
(W)     mov (1|M0)               r9.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r10.0<1>:ud   r1.2<0;0>:ud      r10.0<1;0>:ud     r17.0<1>:ud      {A@2} // s0&(s1|s2)
        and (32|M0)              r14.0<1>:ud   r14.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x2:uw              {I@4}
        bfn.0xEA (32|M0)         r23.0<1>:ud   r10.0<1;0>:ud     r19.0<1;0>:ud     r9.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xA8 (32|M0)         r14.0<1>:ud   r1.2<0;0>:ud      r14.0<1;0>:ud     r7.0<1>:ud       {I@3} // s0&(s1|s2)
(W)     mov (1|M0)               r1.3<1>:f     0x7070707:f
        and (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x3F003F00:ud
        bfn.0xEA (32|M0)         r25.0<1>:ud   r14.0<1;0>:ud     r21.0<1;0>:ud     r9.0<0>:ud       {I@2} // s0|s1&s2
        bfn.0xA8 (32|M0)         r19.0<1>:ud   r1.3<0;0>:ud      r19.0<1;0>:ud     r10.0<1>:ud      {A@1} // s0&(s1|s2)
        and (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x3F003F00:ud
        shr (16|M0)              r3.0<1>:ud    r109.0<1;1,0>:ud  0x18:uw              {Compacted,$7.dst}
        shl (16|M0)              r7.0<1>:d     r110.0<1;1,0>:d   8:w               {Compacted}
        shr (16|M0)              r10.0<1>:ud   r110.0<1;1,0>:ud  0x10:uw              {Compacted}
        shl (16|M0)              r11.0<1>:d    r70.0<1;1,0>:d    16:w               {Compacted,$8.dst}
        mov (32|M0)              r12.0<1>:f    r109.0<1;1,0>:f                  {Compacted}
        bfn.0xA8 (32|M0)         r21.0<1>:ud   r1.3<0;0>:ud      r21.0<1;0>:ud     r14.0<1>:ud      {I@5} // s0&(s1|s2)
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x1:uw              {Compacted}
        or (16|M0)               r13.0<1>:d    r7.0<1;1,0>:d     r3.0<1;1,0>:d    {Compacted,A@1}
        or (16|M0)               r14.0<1>:d    r11.0<1;1,0>:d    r10.0<1;1,0>:d   {Compacted,I@4}
        shr (16|M0)              r15.0<1>:ud   r70.0<1;1,0>:ud   0x8:uw
(W)     mov (1|M0)               r8.0<1>:f     0x70707070:f
        shl (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x1:uw
        and (32|M0)              r16.0<1>:w    r12.0<2;1,0>:w    4095:w               {I@4}
        and (32|M0)              r17.0<1>:w    r14.0<2;1,0>:w    4095:w               {I@3}
        bfn.0xEA (32|M0)         r27.0<1>:ud   r19.0<1;0>:ud     r23.0<1;0>:ud     r8.0<0>:ud       {F@1} // s0|s1&s2
        shl (32|M0)              r12.0<1>:d    r12.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r14.0<1>:ud   r14.0<1;1,0>:ud   0x4:uw              {Compacted}
        mov (32|M0)              r19.0<1>:d    r16.0<1;1,0>:uw                  {I@5}
        mov (32|M0)              r23.0<1>:d    r17.0<1;1,0>:uw                  {I@5}
        bfn.0xEA (32|M0)         r29.0<1>:ud   r21.0<1;0>:ud     r25.0<1;0>:ud     r8.0<0>:ud       // s0|s1&s2
        bfn.0xEA (32|M0)         r21.0<1>:ud   r19.0<1;0>:ud     r12.0<1;0>:ud     r6.0<0>:ud       {I@3} // s0|s1&s2
        bfn.0xEA (32|M0)         r25.0<1>:ud   r23.0<1;0>:ud     r14.0<1;0>:ud     r6.0<0>:ud       {I@3} // s0|s1&s2
        and (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r14.0<1>:ud   r14.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        bfn.0xA8 (32|M0)         r12.0<1>:ud   r1.2<0;0>:ud      r12.0<1;0>:ud     r19.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r14.0<1>:ud   r1.2<0;0>:ud      r14.0<1;0>:ud     r23.0<1>:ud      {I@4} // s0&(s1|s2)
        sync.allwr                           ($3,$12,$13)
        dpas.8x8 (16|M0)         r62:d         r62:d             r27:u4            r79.0:b          {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r46:d         r46:d             r27:u4            r71.0:ub         {$12}
        bfn.0xEA (32|M0)         r27.0<1>:ud   r12.0<1;0>:ud     r21.0<1;0>:ud     r9.0<0>:ud       {@2,$12.src} // s0|s1&s2
        bfn.0xEA (32|M0)         r29.0<1>:ud   r14.0<1;0>:ud     r25.0<1;0>:ud     r9.0<0>:ud       {I@2} // s0|s1&s2
        and (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x3F003F00:ud
        add (1|M0)               r2.6<1>:d     r2.6<0;1,0>:d     4:w
        shl (32|M0)              r27.0<1>:ud   r27.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
        shl (32|M0)              r29.0<1>:ud   r29.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
        bfn.0xA8 (32|M0)         r21.0<1>:ud   r1.3<0;0>:ud      r21.0<1;0>:ud     r12.0<1>:ud      {I@5} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r25.0<1>:ud   r1.3<0;0>:ud      r25.0<1;0>:ud     r14.0<1>:ud      {I@5} // s0&(s1|s2)
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r2.6<0;1,0>:ud    r4.10<0;1,0>:ud  {I@5}
        bfn.0xEA (32|M0)         r31.0<1>:ud   r21.0<1;0>:ud     r27.0<1;0>:ud     r8.0<0>:ud       {I@3} // s0|s1&s2
        bfn.0xEA (32|M0)         r33.0<1>:ud   r25.0<1;0>:ud     r29.0<1;0>:ud     r8.0<0>:ud       {I@3} // s0|s1&s2
        sync.nop                             null                             {I@1}
        sync.allwr                           ($0,$10)
        dpas.8x8 (16|M0)         r54:d         r54:d             r31:u4            r85.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r38:d         r38:d             r31:u4            r75.0:ub         {$9}
        add (1|M0)               r2.2<1>:uq    r84.0<0;1,0>:uq   0xC0:uw
        add (1|M0)               r2.1<1>:uq    r84.0<0;1,0>:uq   384:w
(W&f3.1) jmpi                                L5488
        mov (1|M0)               r84.0<1>:uq   r2.1<0;1,0>:uq                   {@2,$14.src}
(W)     jmpi                                 L5680
        send.ugm (1|M0)          r79      r2  null:0  0x0            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r71      r4  null:0  0x0            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r37.1<0;1,0>:q   {Compacted,$3.src}
        add (1|M0)               r4.0<1>:q     r4.0<0;1,0>:q     r37.1<0;1,0>:q   {Compacted,$13.src}
        send.ugm (1|M0)          r120     r84  null:0  0x180000            0x0220E580           {I@4,$14} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x180]
        send.ugm (1|M0)          r83      r84  null:0  0x200000            0x0210D580           {$15} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x200]
        send.ugm (1|M0)          r109     r84  null:0  0x240000            0x0220E580           {$11} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x240]
        send.ugm (1|M0)          r70      r84  null:0  0x2C0000            0x0210D580           {$1} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x2C0]
        sync.nop                             null                             {$9.src}
        send.ugm (1|M0)          r85      r2  null:0  0x0            0x0240F580           {I@2,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r75      r4  null:0  0x0            0x0240F580           {I@1,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r84.0<1>:uq   r2.2<0;1,0>:uq    0x240:uw              {$1.src}
        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r37.1<0;1,0>:q   {Compacted,$6.src}
        add (1|M0)               r4.0<1>:q     r4.0<0;1,0>:q     r37.1<0;1,0>:q   {Compacted,$2.src}
        shr (16|M0)              r7.0<1>:ud    r36.0<1;1,0>:ud   0x10:uw              {Compacted,$1.dst}
        shl (16|M0)              r8.0<1>:d     r101.0<1;1,0>:d   16:w               {Compacted,$11.dst}
        shr (16|M0)              r3.0<1>:ud    r35.0<1;1,0>:ud   0x18:uw              {Compacted}
        shl (16|M0)              r6.0<1>:d     r36.0<1;1,0>:d    8:w               {Compacted}
        shr (16|M0)              r11.0<1>:ud   r101.0<1;1,0>:ud  0x8:uw              {Compacted}
        or (16|M0)               r10.0<1>:d    r8.0<1;1,0>:d     r7.0<1;1,0>:d    {Compacted,I@4}
        or (16|M0)               r36.0<1>:d    r6.0<1;1,0>:d     r3.0<1;1,0>:d    {Compacted,I@3}
        and (32|M0)              r12.0<1>:w    r10.0<2;1,0>:w    4095:w               {I@2}
        shl (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0x4:uw              {Compacted}
(W)     mov (1|M0)               r13.0<1>:f    0xFFF0000:f
        and (32|M0)              r9.0<1>:w     r35.0<2;1,0>:w    4095:w               {I@3}
        mov (32|M0)              r18.0<1>:d    r12.0<1;1,0>:uw                  {I@3}
        shl (32|M0)              r35.0<1>:d    r35.0<1;1,0>:d    4:w
        mov (32|M0)              r14.0<1>:d    r9.0<1;1,0>:uw                   {I@3}
        bfn.0xEA (32|M0)         r20.0<1>:ud   r18.0<1;0>:ud     r10.0<1;0>:ud     r13.0<0>:ud      {A@1} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        and (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0xFFF0000:ud
        bfn.0xEA (32|M0)         r16.0<1>:ud   r14.0<1;0>:ud     r35.0<1;0>:ud     r13.0<0>:ud      {I@3} // s0|s1&s2
        shl (32|M0)              r20.0<1>:ud   r20.0<1;1,0>:ud   0x2:uw              {I@3}
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r10.0<1>:ud   r1.2<0;0>:ud      r10.0<1;0>:ud     r18.0<1>:ud      {A@2} // s0&(s1|s2)
        and (32|M0)              r35.0<1>:ud   r35.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x2:uw              {I@4}
        bfn.0xEA (32|M0)         r23.0<1>:ud   r10.0<1;0>:ud     r20.0<1;0>:ud     r3.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xA8 (32|M0)         r35.0<1>:ud   r1.2<0;0>:ud      r35.0<1;0>:ud     r14.0<1>:ud      {I@3} // s0&(s1|s2)
(W)     mov (1|M0)               r1.3<1>:f     0x7070707:f
        and (32|M0)              r20.0<1>:ud   r20.0<1;1,0>:ud   0x3F003F00:ud
        shl (16|M0)              r12.0<1>:d    r127.0<1;1,0>:d   8:w               {Compacted,$6.dst}
        shr (16|M0)              r9.0<1>:ud    r126.0<1;1,0>:ud  0x18:uw              {Compacted}
        bfn.0xEA (32|M0)         r7.0<1>:ud    r35.0<1;0>:ud     r16.0<1;0>:ud     r3.0<0>:ud       {I@4} // s0|s1&s2
        shr (16|M0)              r14.0<1>:ud   r127.0<1;1,0>:ud  0x10:uw              {Compacted}
        shl (16|M0)              r15.0<1>:d    r92.0<1;1,0>:d    16:w               {Compacted,$14.dst}
        bfn.0xA8 (32|M0)         r20.0<1>:ud   r1.3<0;0>:ud      r20.0<1;0>:ud     r10.0<1>:ud      {A@1} // s0&(s1|s2)
        and (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x3F003F00:ud
        shl (32|M0)              r7.0<1>:ud    r7.0<1;1,0>:ud    0x1:uw              {Compacted,I@5}
        or (16|M0)               r127.0<1>:d   r12.0<1;1,0>:d    r9.0<1;1,0>:d    {Compacted}
        or (16|M0)               r10.0<1>:d    r15.0<1;1,0>:d    r14.0<1;1,0>:d   {Compacted,I@5}
        shr (16|M0)              r11.0<1>:ud   r92.0<1;1,0>:ud   0x8:uw              {Compacted}
(W)     mov (1|M0)               r6.0<1>:f     0x70707070:f
        bfn.0xA8 (32|M0)         r16.0<1>:ud   r1.3<0;0>:ud      r16.0<1;0>:ud     r35.0<1>:ud      {I@5} // s0&(s1|s2)
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x1:uw
        and (32|M0)              r18.0<1>:w    r126.0<2;1,0>:w   4095:w               {I@5}
        and (32|M0)              r19.0<1>:w    r10.0<2;1,0>:w    4095:w               {I@4}
        bfn.0xEA (32|M0)         r25.0<1>:ud   r16.0<1;0>:ud     r7.0<1;0>:ud      r6.0<0>:ud       {A@1} // s0|s1&s2
        shl (32|M0)              r126.0<1>:d   r126.0<1;1,0>:d   4:w               {Compacted}
        shl (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0x4:uw              {Compacted}
        mov (32|M0)              r16.0<1>:d    r18.0<1;1,0>:uw                  {I@5}
        mov (32|M0)              r7.0<1>:d     r19.0<1;1,0>:uw                  {I@5}
        bfn.0xEA (32|M0)         r27.0<1>:ud   r20.0<1;0>:ud     r23.0<1;0>:ud     r6.0<0>:ud       // s0|s1&s2
        bfn.0xEA (32|M0)         r20.0<1>:ud   r16.0<1;0>:ud     r126.0<1;0>:ud    r13.0<0>:ud      {I@3} // s0|s1&s2
        bfn.0xEA (32|M0)         r23.0<1>:ud   r7.0<1;0>:ud      r10.0<1;0>:ud     r13.0<0>:ud      {I@3} // s0|s1&s2
        and (32|M0)              r126.0<1>:ud  r126.0<1;1,0>:ud  0xFFF0000:ud
        and (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r20.0<1>:ud   r20.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        bfn.0xA8 (32|M0)         r126.0<1>:ud  r1.2<0;0>:ud      r126.0<1;0>:ud    r16.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r10.0<1>:ud   r1.2<0;0>:ud      r10.0<1;0>:ud     r7.0<1>:ud       {I@4} // s0&(s1|s2)
        sync.allwr                           ($5,$12)
        dpas.8x8 (16|M0)         r62:d         r62:d             r25:u4            r97.0:b          {Atomic,$15.dst}
        dpas.8x8 (16|M0)         r46:d         r46:d             r25:u4            r93.0:ub         {$4}
        bfn.0xEA (32|M0)         r25.0<1>:ud   r126.0<1;0>:ud    r20.0<1;0>:ud     r3.0<0>:ud       {@2,$4.src} // s0|s1&s2
        bfn.0xEA (32|M0)         r27.0<1>:ud   r10.0<1;0>:ud     r23.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
        and (32|M0)              r20.0<1>:ud   r20.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x3F003F00:ud
        shl (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
        shl (32|M0)              r27.0<1>:ud   r27.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
        bfn.0xA8 (32|M0)         r20.0<1>:ud   r1.3<0;0>:ud      r20.0<1;0>:ud     r126.0<1>:ud     {I@4} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r23.0<1>:ud   r1.3<0;0>:ud      r23.0<1;0>:ud     r10.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r12.0<1>:ud   r20.0<1;0>:ud     r25.0<1;0>:ud     r6.0<0>:ud       {I@2} // s0|s1&s2
        bfn.0xEA (32|M0)         r14.0<1>:ud   r23.0<1;0>:ud     r27.0<1;0>:ud     r6.0<0>:ud       {I@2} // s0|s1&s2
        sync.nop                             null                             {I@1}
        sync.allwr                           ($4,$9)
        dpas.8x8 (16|M0)         r54:d         r54:d             r12:u4            r115.0:b         {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r38:d         r38:d             r12:u4            r111.0:ub        {$5}
(W&f3.1) jmpi                                L4144
