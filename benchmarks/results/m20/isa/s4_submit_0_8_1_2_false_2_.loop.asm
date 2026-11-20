        add (1|M0)               r3.0<1>:q     r27.0<0;1,0>:q    r24.2<0;1,0>:q   {I@2}
        send.ugm (1|M0)          r7       r27  null:0  0x0            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r5.0<1>:q     r3.0<0;1,0>:q     r24.2<0;1,0>:q   {I@1}
        send.ugm (1|M0)          r15      r26  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r19      r25  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r3  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {$2.src}
        send.ugm (1|M0)          r29      r28  null:0  0x0            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r37      r28  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r33      r5  null:0  0x0            0x0240F580           {I@1,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r24.1<1>:d    r24.1<0;1,0>:d    4:w
        add (1|M0)               r27.0<1>:q    r5.0<0;1,0>:q     r24.2<0;1,0>:q   {$3.src}
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r24.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@2}
        send.ugm (1|M0)          r41      r27  null:0  0x0            0x0240F580           {I@2,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r24.3<1>:uq   r28.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r25.0<1>:uq   r28.0<0;1,0>:uq   512:w               {$5.src}
        add (1|M0)               r27.0<1>:q    r27.0<0;1,0>:q    r24.2<0;1,0>:q   {$10.src}
        sync.allwr                           ($2,$4,$5,$6)
        dpas.8x8 (16|M0)         r48:d         r48:d             r19:s4            r7.0:b           {Atomic,$3.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r15:s4            r11.0:b          {$2}
(W&f1.0) jmpi                                L1856
        sync.allwr                           ($2,$8,$9,$10)
        dpas.8x8 (16|M0)         r48:d         r48:d             r29:s4            r33.0:b          {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r37:s4            r41.0:b          {$7}
(W)     jmpi                                 L2016
        sync.allwr                           ($2,$8,$9,$10)
        dpas.8x8 (16|M0)         r48:d         r48:d             r29:s4            r33.0:b          {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r37:s4            r41.0:b          {$2}
        add (1|M0)               r26.0<1>:uq   r24.3<0;1,0>:uq   0x200:uw              {I@5}
        add (1|M0)               r28.0<1>:uq   r24.3<0;1,0>:uq   0x300:uw
(W)     jmpi                                 L1456
