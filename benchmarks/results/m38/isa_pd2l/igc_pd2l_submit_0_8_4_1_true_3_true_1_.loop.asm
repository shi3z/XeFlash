        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r1.2<0;1,0>:q    {Compacted,I@1}
        add (1|M0)               r4.0<1>:q     r4.0<0;1,0>:q     r1.2<0;1,0>:q
        send.ugm (1|M0)          r153     r1  null:0  0x0            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.allrd                           ($1,$6)
        send.ugm (1|M0)          r189     r1  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($0,$15,$16,$17,$18,$19,$22,$23,$24,$25,$30)
        dpas.8x8 (16|M0)         r42:d         r42:d             r110:s4           r129.0:b         {Atomic,$14.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r110:s4           r123.0:b         {Atomic}
        dpas.8x8 (16|M0)         r58:d         r58:d             r110:s4           r119.0:b         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r110:s4           r115.0:b         {$14}
        sync.allwr                           ($1,$6,$9,$10,$21,$26,$27,$28,$29)
        dpas.8x8 (16|M0)         r74:d         r74:d             r110:s4           r149.0:ub        {Atomic,$20.dst}
        dpas.8x8 (16|M0)         r82:d         r82:d             r110:s4           r145.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r90:d         r90:d             r110:s4           r137.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r110:s4           r133.0:ub        {$20}
        add (1|M0)               r3.0<1>:q     r2.0<0;1,0>:q     r114.1<0;1,0>:q  {Compacted,I@2}
        add (1|M0)               r6.0<1>:q     r4.0<0;1,0>:q     r114.1<0;1,0>:q  {Compacted,I@2}
        add (1|M0)               r1.2<1>:d     r1.2<0;1,0>:d     4:w               {$11.src}
        add (1|M0)               r39.0<1>:q    r3.0<0;1,0>:q     r114.1<0;1,0>:q  {I@3}
        send.ugm (1|M0)          r23      r6  null:0  0x0            0x0240F580           {I@3,$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r27      r6  null:0  0x100000            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r31      r6  null:0  0x200000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r35      r6  null:0  0x300000            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r40.0<1>:q    r6.0<0;1,0>:q     r114.1<0;1,0>:q  {Compacted}
        add (1|M0)               r6.0<1>:q     r39.0<0;1,0>:q    r114.1<0;1,0>:q  {Compacted,@2,$1.src}
        send.ugm (1|M0)          r7       r3  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r3  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r15      r3  null:0  0x200000            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r19      r3  null:0  0x300000            0x0240F580           {$30} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r237     r39  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r233     r39  null:0  0x100000            0x0240F580           {$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r229     r39  null:0  0x200000            0x0240F580           {$16} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r225     r39  null:0  0x300000            0x0240F580           {$17} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r141     r40  null:0  0x0            0x0240F580           {I@2,$19} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r251     r40  null:0  0x100000            0x0240F580           {$21} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r247     r40  null:0  0x200000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r243     r40  null:0  0x300000            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r169     r6  null:0  0x0            0x0240F580           {I@1,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r165     r6  null:0  0x100000            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r161     r6  null:0  0x200000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r157     r6  null:0  0x300000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r1.2<0;1,0>:ud    r4.10<0;1,0>:ud
        add (1|M0)               r3.0<1>:q     r40.0<0;1,0>:q    r114.1<0;1,0>:q  {$30.src}
        send.ugm (1|M0)          r185     r3  null:0  0x0            0x0240F580           {I@1,$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r181     r3  null:0  0x100000            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r177     r3  null:0  0x200000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r173     r3  null:0  0x300000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        sync.allwr                           ($1,$2,$3,$8,$14,$31)
        dpas.8x8 (16|M0)         r42:d         r42:d             r106:s4           r23.0:b          {Atomic,$12.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r106:s4           r27.0:b          {Atomic}
        dpas.8x8 (16|M0)         r58:d         r58:d             r106:s4           r31.0:b          {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r106:s4           r35.0:b          {$12}
        sync.allwr                           ($4,$5,$7,$30)
        dpas.8x8 (16|M0)         r74:d         r74:d             r106:s4           r7.0:ub          {Atomic,$20.dst}
        dpas.8x8 (16|M0)         r82:d         r82:d             r106:s4           r11.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r90:d         r90:d             r106:s4           r15.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r106:s4           r19.0:ub         {$20}
        add (1|M0)               r7.0<1>:q     r3.0<0;1,0>:q     r114.1<0;1,0>:q  {Compacted,$20.src}
        add (1|M0)               r3.0<1>:q     r6.0<0;1,0>:q     r114.1<0;1,0>:q  {Compacted}
(W&~f3.1) jmpi                               L4096
        send.ugm (1|M0)          r110     r1  null:0  0x200000            0x0240F580           {$18} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r129     r7  null:0  0x0            0x0240F580           {I@3,$22} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r123     r7  null:0  0x100000            0x0240F580           {$23} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r119     r7  null:0  0x200000            0x0240F580           {$24} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r115     r7  null:0  0x300000            0x0240F580           {$25} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r149     r3  null:0  0x0            0x0240F580           {I@2,$26} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r145     r3  null:0  0x100000            0x0240F580           {$27} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r137     r3  null:0  0x200000            0x0240F580           {$28} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r133     r3  null:0  0x300000            0x0240F580           {$29} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        sync.allwr                           ($9,$12,$14,$19,$21)
        dpas.8x8 (16|M0)         r42:d         r42:d             r153:s4           r141.0:b         {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r153:s4           r251.0:b         {Atomic}
        dpas.8x8 (16|M0)         r58:d         r58:d             r153:s4           r247.0:b         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r153:s4           r243.0:b         {$19}
        sync.allwr                           ($15,$16,$17,$20)
        dpas.8x8 (16|M0)         r74:d         r74:d             r153:s4           r237.0:ub        {Atomic,$6.dst}
        dpas.8x8 (16|M0)         r82:d         r82:d             r153:s4           r233.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r90:d         r90:d             r153:s4           r229.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r153:s4           r225.0:ub        {$6}
(W&~f3.1) jmpi                               L4416
        send.ugm (1|M0)          r106     r1  null:0  0x300000            0x0240F580           {$31} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        sync.allwr                           ($2,$3,$4,$8,$19)
        dpas.8x8 (16|M0)         r42:d         r42:d             r189:s4           r185.0:b         {Atomic,$11.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r189:s4           r181.0:b         {Atomic}
        dpas.8x8 (16|M0)         r58:d         r58:d             r189:s4           r177.0:b         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r189:s4           r173.0:b         {$0}
        sync.allwr                           ($0,$6,$13)
        dpas.8x8 (16|M0)         r74:d         r74:d             r189:s4           r169.0:ub        {Atomic,$10.dst}
        dpas.8x8 (16|M0)         r82:d         r82:d             r189:s4           r165.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r90:d         r90:d             r189:s4           r161.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r189:s4           r157.0:ub        {$1}
        sync.nop                             null                             {$31.src}
        add (1|M0)               r1.0<1>:uq    r1.0<0;1,0>:uq    0x400:uw              {$18.src}
(W&f3.1) jmpi                                L3176
