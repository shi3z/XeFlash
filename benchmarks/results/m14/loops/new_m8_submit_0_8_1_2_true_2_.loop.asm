        add (1|M0)               r41.0<1>:q    r41.0<0;1,0>:q    r36.3<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r40.0<1>:q    r40.0<0;1,0>:q    r36.3<0;1,0>:q   {Compacted}
        add (1|M0)               r7.0<1>:q     r41.0<0;1,0>:q    r36.2<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r5.0<1>:q     r40.0<0;1,0>:q    r36.2<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r8.0<1>:q     r7.0<0;1,0>:q     r36.2<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r6.0<1>:q     r5.0<0;1,0>:q     r36.2<0;1,0>:q   {I@2}
        send.ugm (1|M0)          r13      r7  null:0  0x0            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r21      r5  null:0  0x0            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r7.0<1>:q     r6.0<0;1,0>:q     r36.2<0;1,0>:q   {Compacted,@1,$0.src}
        add (1|M0)               r5.0<1>:q     r8.0<0;1,0>:q     r36.2<0;1,0>:q   {Compacted,$1.src}
        send.ugm (1|M0)          r25      r39  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r29      r38  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r9       r41  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r17      r40  null:0  0x0            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.allrd                           ($9,$15)
        send.ugm (1|M0)          r42      r37  null:0  0x0            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {$10.src}
        send.ugm (1|M0)          r55      r37  null:0  0x100000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r51      r8  null:0  0x0            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r47      r6  null:0  0x0            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r59      r7  null:0  0x0            0x0240F580           {I@2,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r63      r5  null:0  0x0            0x0240F580           {I@1,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r36.1<1>:d    r36.1<0;1,0>:d    4:w
        add (1|M0)               r36.4<1>:uq   r37.0<0;1,0>:uq   0x100:uw
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r36.1<0;1,0>:ud   r3.0<0;1,0>:ud   {I@2}
        add (1|M0)               r38.0<1>:uq   r37.0<0;1,0>:uq   512:w               {$5.src}
        sync.allwr                           ($0,$1,$4,$5,$6,$7,$10,$15)
        dpas.8x8 (16|M0)         r92:d         r92:d             r25:s4            r21.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r76:d         r76:d             r25:s4            r13.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r84:d         r84:d             r29:s4            r17.0:b          {Atomic}
        dpas.8x8 (16|M0)         r68:d         r68:d             r29:s4            r9.0:ub          {$9}
(W&~f1.0) jmpi                               L2560
        sync.allwr                           ($2,$3,$9,$10,$11,$12)
        dpas.8x8 (16|M0)         r84:d         r84:d             r42:s4            r47.0:b          {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r68:d         r68:d             r42:s4            r51.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r92:d         r92:d             r55:s4            r59.0:b          {Atomic}
        dpas.8x8 (16|M0)         r76:d         r76:d             r55:s4            r63.0:ub         {$15}
        add (1|M0)               r39.0<1>:uq   r36.4<0;1,0>:uq   0x200:uw              {I@4}
        add (1|M0)               r37.0<1>:uq   r36.4<0;1,0>:uq   0x300:uw
(W)     jmpi                                 L1976
