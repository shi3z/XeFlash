        sync.allrd                           ($8,$13)
        send.ugm (1|M0)          r123     r4  null:0  0x0            0x0240F580           {I@6,$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r119     r1  null:0  0x0            0x0240F580           {I@1,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r115     r2  null:0  0x0            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r111     r2  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r107     r3  null:0  0x0            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r99      r3  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r1.10<1>:d    r1.10<0;1,0>:d    2:w               {$2.src}
        sync.allwr                           ($0,$1,$3,$4,$7,$8,$9,$10)
        dpas.8x8 (16|M0)         r74:d         r74:d             r12:s4            r95.0:b          {Atomic,$14.dst}
        dpas.8x8 (16|M0)         r58:d         r58:d             r12:s4            r89.0:b          {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r12:s4            r103.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r50:d         r50:d             r12:s4            r7.0:ub          {$14}
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r1.10<0;1,0>:ud   r4.10<0;1,0>:ud  {I@1}
        sync.nop                             null                             {$6.dst}
        dpas.8x8 (16|M0)         r42:d         r42:d             r84:s4            r95.0:b          {Atomic,$15.dst}
        dpas.8x8 (16|M0)         r26:d         r26:d             r84:s4            r89.0:b          {Atomic}
        dpas.8x8 (16|M0)         r34:d         r34:d             r84:s4            r103.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r18:d         r18:d             r84:s4            r7.0:ub          {$15}
        add (1|M0)               r1.4<1>:uq    r4.0<0;1,0>:uq    0x100:uw
        add (1|M0)               r1.3<1>:uq    r1.0<0;1,0>:uq    0x100:uw
        add (1|M0)               r11.0<1>:q    r2.0<0;1,0>:q     r1.2<0;1,0>:q    {Compacted}
        add (1|M0)               r6.0<1>:q     r3.0<0;1,0>:q     r1.2<0;1,0>:q    {Compacted}
(W&f3.1) jmpi                                L2784
        mov (1|M0)               r2.0<1>:uq    r11.0<0;1,0>:uq                  {Compacted,@3,$8.src}
        mov (1|M0)               r3.0<1>:uq    r6.0<0;1,0>:uq                   {Compacted,@3,$11.src}
        mov (1|M0)               r4.0<1>:uq    r1.4<0;1,0>:uq                   {Compacted,$5.src}
        mov (1|M0)               r1.0<1>:uq    r1.3<0;1,0>:uq                   {Compacted}
(W)     jmpi                                 L2944
        sync.nop                             null                             {Compacted,$14.src}
        send.ugm (1|M0)          r12      r4  null:0  0x100000            0x0240F580           {I@3,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {Compacted,$15.src}
        send.ugm (1|M0)          r84      r1  null:0  0x100000            0x0240F580           {I@2,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r95      r11  null:0  0x0            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r89      r11  null:0  0x100000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r103     r6  null:0  0x0            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r7       r6  null:0  0x100000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r1.1<0;1,0>:q    {Compacted,$8.src}
        add (1|M0)               r3.0<1>:q     r3.0<0;1,0>:q     r1.1<0;1,0>:q    {Compacted,$11.src}
        add (1|M0)               r4.0<1>:uq    r4.0<0;1,0>:uq    0x200:uw              {$7.src}
        add (1|M0)               r1.0<1>:uq    r1.0<0;1,0>:uq    0x200:uw              {$6.src}
        sync.allwr                           ($2,$8,$11,$12,$13,$14,$15)
        dpas.8x8 (16|M0)         r74:d         r74:d             r123:s4           r115.0:b         {Atomic,$5.dst}
        dpas.8x8 (16|M0)         r58:d         r58:d             r123:s4           r111.0:b         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r123:s4           r107.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r50:d         r50:d             r123:s4           r99.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r42:d         r42:d             r119:s4           r115.0:b         {Atomic}
        dpas.8x8 (16|M0)         r26:d         r26:d             r119:s4           r111.0:b         {Atomic}
        dpas.8x8 (16|M0)         r34:d         r34:d             r119:s4           r107.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r18:d         r18:d             r119:s4           r99.0:ub         {$13}
(W&f3.1) jmpi                                L2368
