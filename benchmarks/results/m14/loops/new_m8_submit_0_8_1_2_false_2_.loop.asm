        add (1|M0)               r5.0<1>:q     r27.0<0;1,0>:q    r24.2<0;1,0>:q   {Compacted,I@2}
        send.ugm (1|M0)          r7       r27  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r6.0<1>:q     r5.0<0;1,0>:q     r24.2<0;1,0>:q   {Compacted,I@1}
        send.ugm (1|M0)          r15      r26  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r19      r25  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r5  null:0  0x0            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {Compacted,$3.src}
        send.ugm (1|M0)          r29      r28  null:0  0x0            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r37      r28  null:0  0x100000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r33      r6  null:0  0x0            0x0240F580           {I@1,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r24.1<1>:d    r24.1<0;1,0>:d    4:w
        add (1|M0)               r27.0<1>:q    r6.0<0;1,0>:q     r24.2<0;1,0>:q   {$4.src}
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r24.1<0;1,0>:ud   r3.0<0;1,0>:ud   {I@2}
        send.ugm (1|M0)          r41      r27  null:0  0x0            0x0240F580           {I@2,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r24.3<1>:uq   r28.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r25.0<1>:uq   r28.0<0;1,0>:uq   512:w               {$6.src}
        add (1|M0)               r27.0<1>:q    r27.0<0;1,0>:q    r24.2<0;1,0>:q   {$11.src}
        sync.allwr                           ($3,$5,$6,$7)
        dpas.8x8 (16|M0)         r48:d         r48:d             r19:s4            r7.0:b           {Atomic,$4.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r15:s4            r11.0:b          {$3}
(W&f1.0) jmpi                                L1824
        sync.allwr                           ($3,$9,$10,$11)
        dpas.8x8 (16|M0)         r48:d         r48:d             r29:s4            r33.0:b          {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r37:s4            r41.0:b          {$8}
(W)     jmpi                                 L1984
        sync.allwr                           ($3,$9,$10,$11)
        dpas.8x8 (16|M0)         r48:d         r48:d             r29:s4            r33.0:b          {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r37:s4            r41.0:b          {$3}
        add (1|M0)               r26.0<1>:uq   r24.3<0;1,0>:uq   0x200:uw              {I@5}
        add (1|M0)               r28.0<1>:uq   r24.3<0;1,0>:uq   0x300:uw
(W)     jmpi                                 L1448
