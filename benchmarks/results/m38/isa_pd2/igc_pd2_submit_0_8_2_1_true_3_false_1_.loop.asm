        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r1.2<0;1,0>:q    {Compacted,I@1}
        add (1|M0)               r4.0<1>:q     r4.0<0;1,0>:q     r1.2<0;1,0>:q    {Compacted}
        sync.nop                             null                             {Compacted,$13.src}
        add (1|M0)               r3.0<1>:q     r2.0<0;1,0>:q     r68.3<0;1,0>:q   {Compacted,@2,$8.src}
        add (1|M0)               r6.0<1>:q     r4.0<0;1,0>:q     r68.3<0;1,0>:q   {Compacted,@2,$12.src}
        add (1|M0)               r23.0<1>:q    r3.0<0;1,0>:q     r68.3<0;1,0>:q   {Compacted,@2,$4.src}
        send.ugm (1|M0)          r15      r6  null:0  0x0            0x0240F580           {I@2,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r19      r6  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r24.0<1>:q    r6.0<0;1,0>:q     r68.3<0;1,0>:q   {Compacted}
        add (1|M0)               r6.0<1>:q     r23.0<0;1,0>:q    r68.3<0;1,0>:q   {Compacted,@2,$5.src}
        send.ugm (1|M0)          r7       r3  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r3  null:0  0x100000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r103     r1  null:0  0x0            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {$3.src}
        send.ugm (1|M0)          r119     r1  null:0  0x100000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r91      r23  null:0  0x0            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r87      r23  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r99      r24  null:0  0x0            0x0240F580           {I@2,$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r95      r24  null:0  0x100000            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r107     r6  null:0  0x0            0x0240F580           {I@1,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r3.0<1>:q     r24.0<0;1,0>:q    r68.3<0;1,0>:q   {$9.src}
        send.ugm (1|M0)          r23      r6  null:0  0x100000            0x0240F580           {I@1,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($0,$1,$3,$7,$8,$10,$12,$15)
        dpas.8x8 (16|M0)         r28:d         r28:d             r64:s4            r73.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r36:d         r36:d             r64:s4            r69.0:b          {Atomic}
        dpas.8x8 (16|M0)         r44:d         r44:d             r64:s4            r83.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r52:d         r52:d             r64:s4            r77.0:ub         {$3}
        add (1|M0)               r1.2<1>:d     r1.2<0;1,0>:d     4:w
        send.ugm (1|M0)          r115     r3  null:0  0x0            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        cmp (1|M0)    (lt)f3.0   null<1>:ud    r1.2<0;1,0>:ud    r4.10<0;1,0>:ud  {I@1}
        send.ugm (1|M0)          r111     r3  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($2,$3,$4,$5,$6,$9)
        dpas.8x8 (16|M0)         r28:d         r28:d             r60:s4            r15.0:b          {Atomic,$14.dst}
        dpas.8x8 (16|M0)         r36:d         r36:d             r60:s4            r19.0:b          {Atomic}
        dpas.8x8 (16|M0)         r44:d         r44:d             r60:s4            r7.0:ub          {Atomic}
        dpas.8x8 (16|M0)         r52:d         r52:d             r60:s4            r11.0:ub         {$2}
        add (1|M0)               r7.0<1>:q     r3.0<0;1,0>:q     r68.3<0;1,0>:q   {Compacted,$2.src}
        add (1|M0)               r3.0<1>:q     r6.0<0;1,0>:q     r68.3<0;1,0>:q   {Compacted}
(W&~f3.0) jmpi                               L3008
        send.ugm (1|M0)          r64      r1  null:0  0x200000            0x0240F580           {$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r73      r7  null:0  0x0            0x0240F580           {I@3,$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r69      r7  null:0  0x100000            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r83      r3  null:0  0x0            0x0240F580           {I@2,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r77      r3  null:0  0x100000            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($2,$7,$8,$13,$14)
        dpas.8x8 (16|M0)         r28:d         r28:d             r103:s4           r99.0:b          {Atomic,$10.dst}
        dpas.8x8 (16|M0)         r36:d         r36:d             r103:s4           r95.0:b          {Atomic}
        dpas.8x8 (16|M0)         r44:d         r44:d             r103:s4           r91.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r52:d         r52:d             r103:s4           r87.0:ub         {$7}
(W&~f3.0) jmpi                               L3184
        send.ugm (1|M0)          r60      r1  null:0  0x300000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        sync.allwr                           ($3,$5,$6,$7,$11)
        dpas.8x8 (16|M0)         r28:d         r28:d             r119:s4           r115.0:b         {Atomic,$12.dst}
        dpas.8x8 (16|M0)         r36:d         r36:d             r119:s4           r111.0:b         {Atomic}
        dpas.8x8 (16|M0)         r44:d         r44:d             r119:s4           r107.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r52:d         r52:d             r119:s4           r23.0:ub         {$4}
        sync.nop                             null                             {Compacted,$2.src}
        add (1|M0)               r1.0<1>:uq    r1.0<0;1,0>:uq    0x400:uw              {$15.src}
(W&f3.0) jmpi                                L2448
