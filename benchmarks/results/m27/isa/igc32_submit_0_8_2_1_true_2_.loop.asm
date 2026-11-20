        send.ugm (1|M0)          r43      r38  null:0  0x0            0x0240F580           {I@5,$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r47      r37  null:0  0x0            0x0240F580           {I@4,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r51      r37  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r55      r24  null:0  0x0            0x0240F580           {I@3,$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r63      r24  null:0  0x100000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r16.1<1>:d    r16.1<0;1,0>:d    2:w               {I@1}
        sync.allwr                           ($0,$1,$3,$7,$9,$10,$11,$13,$14,$15)
        dpas.8x8 (16|M0)         r96:d         r96:d             r83:s4            r75.0:b          {Atomic,$12.dst}
        dpas.8x8 (16|M0)         r88:d         r88:d             r83:s4            r79.0:b          {Atomic}
        dpas.8x8 (16|M0)         r112:d        r112:d            r83:s4            r67.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r104:d        r104:d            r83:s4            r71.0:ub         {$12}
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r16.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@1}
        add (1|M0)               r16.4<1>:uq   r38.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r59.0<1>:q    r37.0<0;1,0>:q    r16.2<0;1,0>:q   {Compacted}
        add (1|M0)               r60.0<1>:q    r24.0<0;1,0>:q    r16.2<0;1,0>:q   {Compacted}
(W&f3.1) jmpi                                L2328
        mov (1|M0)               r37.0<1>:uq   r59.0<0;1,0>:uq                  {Compacted,@3,$4.src}
        mov (1|M0)               r24.0<1>:uq   r60.0<0;1,0>:uq                  {Compacted,@3,$6.src}
        mov (1|M0)               r38.0<1>:uq   r16.4<0;1,0>:uq                  {Compacted,$8.src}
(W)     jmpi                                 L2448
        sync.nop                             null                             {Compacted,$12.src}
        send.ugm (1|M0)          r83      r38  null:0  0x100000            0x0240F580           {I@2,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r75      r59  null:0  0x0            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r79      r59  null:0  0x100000            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r67      r60  null:0  0x0            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r71      r60  null:0  0x100000            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r37.0<1>:q    r37.0<0;1,0>:q    r16.3<0;1,0>:q   {Compacted,$4.src}
        add (1|M0)               r24.0<1>:q    r24.0<0;1,0>:q    r16.3<0;1,0>:q   {Compacted,$6.src}
        add (1|M0)               r38.0<1>:uq   r38.0<0;1,0>:uq   0x200:uw              {$9.src}
        sync.allwr                           ($2,$4,$5,$6,$12)
        dpas.8x8 (16|M0)         r96:d         r96:d             r43:s4            r47.0:b          {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r88:d         r88:d             r43:s4            r51.0:b          {Atomic}
        dpas.8x8 (16|M0)         r112:d        r112:d            r43:s4            r55.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r104:d        r104:d            r43:s4            r63.0:ub         {$8}
(W&f3.1) jmpi                                L2048
