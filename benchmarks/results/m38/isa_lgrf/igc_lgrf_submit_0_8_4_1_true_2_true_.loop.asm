        sync.allrd                           ($0,$14)
        send.ugm (1|M0)          r54      r1  null:0  0x0            0x0240F580           {I@1,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r123     r2  null:0  0x100000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r119     r2  null:0  0x200000            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r115     r2  null:0  0x300000            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r1.10<1>:d    r1.10<0;1,0>:d    2:w               {$2.src}
        shl (1|M0)               r1.7<1>:q     r4.6<0;1,0>:q     5:w
        cmp (1|M0)    (lt)f0.1   null<1>:ud    r1.10<0;1,0>:ud   r4.10<0;1,0>:ud  {I@2}
        sync.allwr                           ($0,$1,$6,$7,$8,$10,$11,$12,$13,$15)
        dpas.8x8 (16|M0)         r71:d         r71:d             r79:s4            r95.0:b          {Atomic,$5.dst}
        dpas.8x8 (16|M0)         r46:d         r46:d             r79:s4            r91.0:b          {Atomic}
        dpas.8x8 (16|M0)         r22:d         r22:d             r79:s4            r87.0:b          {Atomic}
        dpas.8x8 (16|M0)         r30:d         r30:d             r79:s4            r83.0:b          {$10}
        sync.nop                             null                             {$4.dst}
        dpas.8x8 (16|M0)         r63:d         r63:d             r79:s4            r111.0:ub        {Atomic,$14.dst}
        dpas.8x8 (16|M0)         r38:d         r38:d             r79:s4            r107.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r6:d          r6:d              r79:s4            r103.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r14:d         r14:d             r79:s4            r99.0:ub         {$14}
        add (1|M0)               r1.6<1>:uq    r1.0<0;1,0>:uq    0x100:uw
(W)     send.ugm (1|M0)          null     r3  r54:4  0x80000000:a0.1        0x4200F504           {$2} // wr:1+4, rd:0; store.ugm.d32x64t.a32.ss[a0.1][A-0x10000]
        sync.nop                             null                             {$2.src}
        send.ugm (1|M0)          r54      r4  null:0  0x0            0x0240F580           {$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
(W)     send.ugm (1|M0)          null     r3  r54:4  0x80800000:a0.1        0x4200F504           {$15} // wr:1+4, rd:0; store.ugm.d32x64t.a32.ss[a0.1][A-0xFF00]
        send.ugm (1|M0)          r54      r4  null:0  0x100000            0x0240F580           {$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
(W)     send.ugm (1|M0)          null     r3  r54:4  0x81000000:a0.1        0x4200F504           {$15} // wr:1+4, rd:0; store.ugm.d32x64t.a32.ss[a0.1][A-0xFE00]
        sync.nop                             null                             {$15.src}
        send.ugm (1|M0)          r54      r4  null:0  0x200000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
(W)     send.ugm (1|M0)          null     r3  r54:4  0x81800000:a0.1        0x4200F504           {$0} // wr:1+4, rd:0; store.ugm.d32x64t.a32.ss[a0.1][A-0xFD00]
        send.ugm (1|M0)          r54      r4  null:0  0x300000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
(W)     send.ugm (1|M0)          null     r3  r54:4  0x82200000:a0.1        0x4200F504           {$0} // wr:1+4, rd:0; store.ugm.d32x64t.a32.ss[a0.1][A-0xFBC0]
        send.ugm (1|M0)          r54      r2  null:0  0x0            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64
(W)     send.ugm (1|M0)          null     r3  r54:4  0x82A00000:a0.1        0x4200F504           {$0} // wr:1+4, rd:0; store.ugm.d32x64t.a32.ss[a0.1][A-0xFAC0]
        add (1|M0)               r54.0<1>:q    r4.0<0;1,0>:q     r1.7<0;1,0>:q    {Compacted,@3,$0.src}
        add (1|M0)               r55.0<1>:q    r2.0<0;1,0>:q     r1.7<0;1,0>:q    {Compacted}
(W&f0.1) jmpi                                L3576
        mov (1|M0)               r4.0<1>:uq    r54.0<0;1,0>:uq                  {Compacted,I@3}
        mov (1|M0)               r2.0<1>:uq    r55.0<0;1,0>:uq                  {Compacted,I@3}
        mov (1|M0)               r1.0<1>:uq    r1.6<0;1,0>:uq                   {Compacted}
(W)     jmpi                                 L3776
        shl (1|M0)               r89.0<1>:q    r4.6<0;1,0>:q     6:w               {Compacted,$10.src}
        sync.nop                             null                             {$14.src}
        send.ugm (1|M0)          r79      r1  null:0  0x100000            0x0240F580           {I@3,$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r95      r54  null:0  0x0            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r91      r54  null:0  0x100000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r83      r54  null:0  0x300000            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r111     r55  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r107     r55  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r103     r55  null:0  0x200000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r99      r55  null:0  0x300000            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r4.0<1>:q     r4.0<0;1,0>:q     r89.0<0;1,0>:q   {Compacted,I@1}
        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r89.0<0;1,0>:q   {Compacted}
        send.ugm (1|M0)          r87      r54  null:0  0x200000            0x0240F580           {I@1,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        add (1|M0)               r1.0<1>:uq    r1.0<0;1,0>:uq    0x200:uw              {$1.src}
        sync.allrd                           ($7,$12)
(W)     send.ugm (1|M0)          r54      r3  null:0  0x80000000:a0.1        0x4240F500           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a32.ss[a0.1][A-0x10000]
(W)     send.ugm (1|M0)          r58      r3  null:0  0x80800000:a0.1        0x4240F500           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a32.ss[a0.1][A-0xFF00]
        sync.allwr                           ($9,$10,$14)
        dpas.8x8 (16|M0)         r71:d         r71:d             r54:s4            r58.0:b          {$8}
(W)     send.ugm (1|M0)          r58      r3  null:0  0x81000000:a0.1        0x4240F500           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a32.ss[a0.1][A-0xFE00]
        sync.nop                             null                             {$8.dst}
        dpas.8x8 (16|M0)         r46:d         r46:d             r54:s4            r58.0:b          {$11}
(W)     send.ugm (1|M0)          r58      r3  null:0  0x81800000:a0.1        0x4240F500           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a32.ss[a0.1][A-0xFD00]
        sync.nop                             null                             {Compacted,$11.dst}
        dpas.8x8 (16|M0)         r22:d         r22:d             r54:s4            r58.0:b          {$13}
        sync.nop                             null                             {Compacted,$13.src}
(W)     send.ugm (1|M0)          r58      r3  null:0  0x82200000:a0.1        0x4240F500           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a32.ss[a0.1][A-0xFBC0]
        sync.nop                             null                             {Compacted,$1.dst}
        dpas.8x8 (16|M0)         r30:d         r30:d             r54:s4            r58.0:b          {$15}
        sync.nop                             null                             {Compacted,$15.src}
(W)     send.ugm (1|M0)          r58      r3  null:0  0x82A00000:a0.1        0x4240F500           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a32.ss[a0.1][A-0xFAC0]
        sync.allwr                           ($3,$10,$13)
        dpas.8x8 (16|M0)         r63:d         r63:d             r54:s4            r58.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r38:d         r38:d             r54:s4            r123.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r6:d          r6:d              r54:s4            r119.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r14:d         r14:d             r54:s4            r115.0:ub        {$0}
(W&f0.1) jmpi                                L2992
