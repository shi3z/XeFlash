        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r45      r39  null:0  0x0            0x0240F580           {I@5,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r49      r38  null:0  0x0            0x0240F580           {I@4,$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r53      r38  null:0  0x100000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r57      r37  null:0  0x0            0x0240F580           {I@3,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r65      r37  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r17.1<1>:d    r17.1<0;1,0>:d    2:w               {I@1}
        sync.allwr                           ($0,$1,$2,$4,$5,$8,$10,$11,$12,$14,$15)
        dpas.8x8 (16|M0)         r98:d         r98:d             r85:s4            r77.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r90:d         r90:d             r85:s4            r81.0:b          {Atomic}
        dpas.8x8 (16|M0)         r114:d        r114:d            r85:s4            r69.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r106:d        r106:d            r85:s4            r73.0:ub         {$13}
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r17.1<0;1,0>:ud   r3.0<0;1,0>:ud   {I@1}
        add (1|M0)               r17.4<1>:uq   r39.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r40.0<1>:q    r38.0<0;1,0>:q    r17.2<0;1,0>:q   {Compacted}
        add (1|M0)               r61.0<1>:q    r37.0<0;1,0>:q    r17.2<0;1,0>:q   {Compacted}
(W&f3.1) jmpi                                L2320
        mov (1|M0)               r38.0<1>:uq   r40.0<0;1,0>:uq                  {Compacted,@3,$6.src}
        mov (1|M0)               r37.0<1>:uq   r61.0<0;1,0>:uq                  {Compacted,@3,$8.src}
        mov (1|M0)               r39.0<1>:uq   r17.4<0;1,0>:uq                  {$9.src}
(W)     jmpi                                 L2448
        sync.nop                             null                             {$13.src}
        send.ugm (1|M0)          r85      r39  null:0  0x100000            0x0240F580           {I@2,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r77      r40  null:0  0x0            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r81      r40  null:0  0x100000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r69      r61  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r73      r61  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r38.0<1>:q    r38.0<0;1,0>:q    r17.3<0;1,0>:q   {Compacted,$6.src}
        add (1|M0)               r37.0<1>:q    r37.0<0;1,0>:q    r17.3<0;1,0>:q   {Compacted,$8.src}
        add (1|M0)               r39.0<1>:uq   r39.0<0;1,0>:uq   0x200:uw              {$10.src}
        sync.allwr                           ($3,$6,$7,$8,$13)
        dpas.8x8 (16|M0)         r98:d         r98:d             r45:s4            r49.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r90:d         r90:d             r45:s4            r53.0:b          {Atomic}
        dpas.8x8 (16|M0)         r114:d        r114:d            r45:s4            r57.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r106:d        r106:d            r45:s4            r65.0:ub         {$2}
(W&f3.1) jmpi                                L2024
