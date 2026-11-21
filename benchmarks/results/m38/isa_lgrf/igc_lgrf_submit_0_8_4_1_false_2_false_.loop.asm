        send.ugm (1|M0)          r91      r4  null:0  0x0            0x0240F580           {I@4,$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r87      r1  null:0  0x0            0x0240F580           {I@1,$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r83      r1  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r79      r1  null:0  0x200000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r75      r1  null:0  0x300000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r1.8<1>:d     r1.8<0;1,0>:d     2:w               {$6.src}
        sync.allwr                           ($0,$1,$2,$7,$9,$10,$11,$13,$14,$15)
        dpas.8x8 (16|M0)         r42:d         r42:d             r52:s4            r71.0:b          {Atomic,$12.dst}
        dpas.8x8 (16|M0)         r18:d         r18:d             r52:s4            r65.0:b          {Atomic}
        dpas.8x8 (16|M0)         r26:d         r26:d             r52:s4            r61.0:b          {Atomic}
        dpas.8x8 (16|M0)         r34:d         r34:d             r52:s4            r57.0:b          {$12}
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r1.8<0;1,0>:ud    r4.10<0;1,0>:ud  {I@1}
        add (1|M0)               r1.3<1>:uq    r4.0<0;1,0>:uq    0x100:uw
        add (1|M0)               r2.0<1>:q     r1.0<0;1,0>:q     r1.2<0;1,0>:q    {Compacted}
(W&f3.1) jmpi                                L2264
        mov (1|M0)               r1.0<1>:uq    r2.0<0;1,0>:uq                   {Compacted,I@2}
        mov (1|M0)               r4.0<1>:uq    r1.3<0;1,0>:uq                   {Compacted,$8.src}
(W)     jmpi                                 L2384
        sync.nop                             null                             {Compacted,$12.src}
        send.ugm (1|M0)          r52      r4  null:0  0x100000            0x0240F580           {I@2,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r71      r2  null:0  0x0            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r65      r2  null:0  0x100000            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r61      r2  null:0  0x200000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r57      r2  null:0  0x300000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r1.0<1>:q     r1.0<0;1,0>:q     r1.1<0;1,0>:q
        add (1|M0)               r4.0<1>:uq    r4.0<0;1,0>:uq    0x200:uw              {$9.src}
        sync.allwr                           ($3,$4,$5,$6,$12)
        dpas.8x8 (16|M0)         r42:d         r42:d             r91:s4            r87.0:b          {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r18:d         r18:d             r91:s4            r83.0:b          {Atomic}
        dpas.8x8 (16|M0)         r26:d         r26:d             r91:s4            r79.0:b          {Atomic}
        dpas.8x8 (16|M0)         r34:d         r34:d             r91:s4            r75.0:b          {$8}
(W&f3.1) jmpi                                L2000
