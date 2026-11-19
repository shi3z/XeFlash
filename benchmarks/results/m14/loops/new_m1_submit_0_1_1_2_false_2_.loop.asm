        add (1|M0)               r25.0<1>:q    r23.0<0;1,0>:q    r1.5<0;1,0>:q    {Compacted,I@2}
        send.ugm (1|M0)          r27      r23  null:0  0x0            0x0210C580           {$5} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r26.0<1>:q    r25.0<0;1,0>:q    r1.5<0;1,0>:q    {Compacted,I@1}
        send.ugm (1|M0)          r32      r22  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r36      r21  null:0  0x0            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r29      r25  null:0  0x0            0x0210C580           {$8} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {$3.src}
        send.ugm (1|M0)          r40      r24  null:0  0x0            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {$4.src}
        send.ugm (1|M0)          r44      r24  null:0  0x100000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r31      r26  null:0  0x0            0x0210C580           {I@1,$11} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r1.5<1>:d     r1.5<0;1,0>:d     4:w
        add (1|M0)               r23.0<1>:q    r26.0<0;1,0>:q    r1.5<0;1,0>:q    {$5.src}
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r1.5<0;1,0>:ud    r3.0<0;1,0>:ud   {I@2}
        send.ugm (1|M0)          r49      r23  null:0  0x0            0x0210C580           {I@2,$12} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r1.6<1>:uq    r24.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r21.0<1>:uq   r24.0<0;1,0>:uq   512:w               {$7.src}
        add (1|M0)               r23.0<1>:q    r23.0<0;1,0>:q    r1.5<0;1,0>:q    {Compacted,$12.src}
        sync.nop                             null                             {Compacted,F@1}
        sync.allwr                           ($5,$7)
        dpas.8x1 (16|M0)         r28:d         r28:d             r36:s4            r27.0:b          {Compacted,$3}
        sync.allwr                           ($6,$8)
        dpas.8x1 (16|M0)         r30:d         r30:d             r32:s4            r29.0:b          {Compacted,$4}
(W&f1.0) jmpi                                L1840
        sync.allwr                           ($3,$11)
        dpas.8x1 (16|M0)         r28:d         r28:d             r40:s4            r31.0:b          {Compacted,$9}
        sync.allwr                           ($4,$12)
        dpas.8x1 (16|M0)         r30:d         r30:d             r44:s4            r49.0:b          {Compacted,$10}
(W)     jmpi                                 L1952
        sync.allwr                           ($9,$11)
        dpas.8x1 (16|M0)         r28:d         r28:d             r40:s4            r31.0:b          {Compacted,$3}
        sync.allwr                           ($10,$12)
        dpas.8x1 (16|M0)         r30:d         r30:d             r44:s4            r49.0:b          {Compacted,$4}
        add (1|M0)               r22.0<1>:uq   r1.6<0;1,0>:uq    0x200:uw              {I@5}
        add (1|M0)               r24.0<1>:uq   r1.6<0;1,0>:uq    0x300:uw
(W)     jmpi                                 L1440
