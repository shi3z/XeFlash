        add (1|M0)               r123.0<1>:q   r123.0<0;1,0>:q   r126.1<0;1,0>:q  {Compacted,I@2}
        add (1|M0)               r35.0<1>:q    r35.0<0;1,0>:q    r126.1<0;1,0>:q  {Compacted}
        add (1|M0)               r7.0<1>:q     r123.0<0;1,0>:q   r33.1<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r3.0<1>:q     r35.0<0;1,0>:q    r33.1<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r8.0<1>:q     r7.0<0;1,0>:q     r33.1<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r6.0<1>:q     r3.0<0;1,0>:q     r33.1<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r27.0<1>:q    r8.0<0;1,0>:q     r33.1<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r26.0<1>:q    r6.0<0;1,0>:q     r33.1<0;1,0>:q   {Compacted,I@2}
        send.ugm (1|M0)          r18      r124  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r22      r34  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r9       r123  null:0  0x0            0x0210C580           {$3} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r13      r35  null:0  0x0            0x0210C580           {$2} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r11      r7  null:0  0x0            0x0210C580           {$4} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r15      r3  null:0  0x0            0x0210C580           {$7} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.allrd                           ($11,$14)
        send.ugm (1|M0)          r36      r125  null:0  0x0            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.allrd                           ($1,$13)
        send.ugm (1|M0)          r40      r125  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r119     r8  null:0  0x0            0x0210C580           {$9} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.allrd                           ($8,$15)
        send.ugm (1|M0)          r121     r6  null:0  0x0            0x0210C580           {$13} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r115     r27  null:0  0x0            0x0210C580           {I@2,$10} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.allrd                           ($0,$9)
        send.ugm (1|M0)          r117     r26  null:0  0x0            0x0210C580           {I@1,$12} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r33.4<1>:d    r33.4<0;1,0>:d    4:w
        add (1|M0)               r126.2<1>:uq  r125.0<0;1,0>:uq  0x100:uw
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r33.4<0;1,0>:ud   r4.10<0;1,0>:ud  {I@2}
        add (1|M0)               r34.0<1>:uq   r125.0<0;1,0>:uq  512:w               {$6.src}
        sync.allwr                           ($2,$6,$8)
        dpas.8x1 (16|M0)         r48:d         r48:d             r22:s4            r13.0:b          {$15}
        sync.allwr                           ($3,$11)
        dpas.8x1 (16|M0)         r44:d         r44:d             r22:s4            r9.0:ub          {$14}
        sync.allwr                           ($5,$7,$9)
        dpas.8x1 (16|M0)         r52:d         r52:d             r18:s4            r15.0:b          {$0}
        sync.allwr                           ($4,$13)
        dpas.8x1 (16|M0)         r46:d         r46:d             r18:s4            r11.0:ub         {$1}
(W&~f1.0) jmpi                               L2608
        sync.allwr                           ($8,$13)
        dpas.8x1 (16|M0)         r48:d         r48:d             r36:s4            r121.0:b         {Compacted,$15}
        sync.nop                             null                             {Compacted,$9.dst}
        dpas.8x1 (16|M0)         r44:d         r44:d             r36:s4            r119.0:ub        {$14}
        sync.allwr                           ($11,$12)
        dpas.8x1 (16|M0)         r52:d         r52:d             r40:s4            r117.0:b         {Compacted,$0}
        sync.nop                             null                             {Compacted,$10.dst}
        dpas.8x1 (16|M0)         r46:d         r46:d             r40:s4            r115.0:ub        {$1}
        add (1|M0)               r124.0<1>:uq  r126.2<0;1,0>:uq  0x200:uw              {I@4}
        add (1|M0)               r125.0<1>:uq  r126.2<0;1,0>:uq  0x300:uw
(W)     jmpi                                 L1936
