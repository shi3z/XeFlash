        sync.nop                             null                             {Compacted,$18.src}
        send.ugm (1|M0)          r53      r39  null:0  0x0            0x0240F580           {I@5,$30} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r65      r38  null:0  0x0            0x0240F580           {I@4,$19} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r73      r38  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r77      r38  null:0  0x200000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r81      r38  null:0  0x300000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r89      r37  null:0  0x0            0x0240F580           {I@3,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r93      r37  null:0  0x100000            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r97      r37  null:0  0x200000            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r105     r37  null:0  0x300000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r17.1<1>:d    r17.1<0;1,0>:d    2:w               {I@1}
        sync.allwr                           ($0,$1,$11,$12,$21,$22,$23,$28,$29,$31)
        dpas.8x8 (16|M0)         r162:d        r162:d            r133:s4           r117.0:b         {Atomic,$20.dst}
        dpas.8x8 (16|M0)         r154:d        r154:d            r133:s4           r121.0:b         {Atomic}
        dpas.8x8 (16|M0)         r146:d        r146:d            r133:s4           r125.0:b         {Atomic}
        dpas.8x8 (16|M0)         r138:d        r138:d            r133:s4           r129.0:b         {$20}
        sync.allwr                           ($13,$14,$15,$16,$17,$18,$25,$26,$27)
        dpas.8x8 (16|M0)         r194:d        r194:d            r133:s4           r85.0:ub         {Atomic,$24.dst}
        dpas.8x8 (16|M0)         r186:d        r186:d            r133:s4           r101.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r178:d        r178:d            r133:s4           r109.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r170:d        r170:d            r133:s4           r113.0:ub        {$24}
        add (1|M0)               r17.4<1>:uq   r39.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r40.0<1>:q    r38.0<0;1,0>:q    r17.2<0;1,0>:q   {Compacted}
        cmp (1|M0)    (lt)f0.1   null<1>:ud    r17.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@3}
        add (1|M0)               r69.0<1>:q    r37.0<0;1,0>:q    r17.2<0;1,0>:q   {Compacted}
(W&f0.1) jmpi                                L2968
        mov (1|M0)               r38.0<1>:uq   r40.0<0;1,0>:uq                  {Compacted,@4,$6.src}
        mov (1|M0)               r37.0<1>:uq   r69.0<0;1,0>:uq                  {Compacted,@3,$8.src}
        mov (1|M0)               r39.0<1>:uq   r17.4<0;1,0>:uq                  {Compacted,$30.src}
(W)     jmpi                                 L3168
        sync.nop                             null                             {Compacted,$24.src}
        send.ugm (1|M0)          r133     r39  null:0  0x100000            0x0240F580           {I@2,$31} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {$20.src}
        send.ugm (1|M0)          r117     r40  null:0  0x0            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r121     r40  null:0  0x100000            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r125     r40  null:0  0x200000            0x0240F580           {$29} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r129     r40  null:0  0x300000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r85      r69  null:0  0x0            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r101     r69  null:0  0x100000            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r109     r69  null:0  0x200000            0x0240F580           {$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r113     r69  null:0  0x300000            0x0240F580           {$17} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r38.0<1>:q    r38.0<0;1,0>:q    r17.3<0;1,0>:q   {Compacted,$6.src}
        add (1|M0)               r37.0<1>:q    r37.0<0;1,0>:q    r17.3<0;1,0>:q   {Compacted,$8.src}
        add (1|M0)               r39.0<1>:uq   r39.0<0;1,0>:uq   0x200:uw              {$31.src}
        sync.allwr                           ($4,$5,$6,$19,$20)
        dpas.8x8 (16|M0)         r162:d        r162:d            r53:s4            r65.0:b          {Atomic,$30.dst}
        dpas.8x8 (16|M0)         r154:d        r154:d            r53:s4            r73.0:b          {Atomic}
        dpas.8x8 (16|M0)         r146:d        r146:d            r53:s4            r77.0:b          {Atomic}
        dpas.8x8 (16|M0)         r138:d        r138:d            r53:s4            r81.0:b          {$30}
        sync.allwr                           ($3,$7,$8,$24)
        dpas.8x8 (16|M0)         r194:d        r194:d            r53:s4            r89.0:ub         {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r186:d        r186:d            r53:s4            r93.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r178:d        r178:d            r53:s4            r97.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r170:d        r170:d            r53:s4            r105.0:ub        {$18}
(W&f0.1) jmpi                                L2536
