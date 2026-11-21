        sync.nop                             null                             {$23.src}
        send.ugm (1|M0)          r55      r43  null:0  0x0            0x0240F580           {I@6,$24} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r59      r42  null:0  0x0            0x0240F580           {I@5,$28} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r63      r41  null:0  0x0            0x0240F580           {I@4,$29} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r67      r41  null:0  0x100000            0x0240F580           {$30} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r79      r32  null:0  0x0            0x0240F580           {I@3,$31} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r83      r32  null:0  0x100000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r19.8<1>:d    r19.8<0;1,0>:d    2:w               {I@1}
        sync.allwr                           ($8,$15,$16,$17,$18,$19,$20,$21,$22,$23,$25,$26,$27)
        dpas.8x8 (16|M0)         r122:d        r122:d            r99:s4            r87.0:b          {Atomic,$14.dst}
        dpas.8x8 (16|M0)         r106:d        r106:d            r99:s4            r91.0:b          {Atomic}
        dpas.8x8 (16|M0)         r154:d        r154:d            r99:s4            r71.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r138:d        r138:d            r99:s4            r75.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r130:d        r130:d            r95:s4            r87.0:b          {Atomic}
        dpas.8x8 (16|M0)         r114:d        r114:d            r95:s4            r91.0:b          {Atomic}
        dpas.8x8 (16|M0)         r162:d        r162:d            r95:s4            r71.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r146:d        r146:d            r95:s4            r75.0:ub         {$14}
        cmp (1|M0)    (lt)f0.1   null<1>:ud    r19.8<0;1,0>:ud   r4.10<0;1,0>:ud  {I@1}
        add (1|M0)               r19.5<1>:uq   r43.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r19.6<1>:uq   r42.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r44.0<1>:q    r41.0<0;1,0>:q    r19.2<0;1,0>:q   {Compacted}
        add (1|M0)               r45.0<1>:q    r32.0<0;1,0>:q    r19.2<0;1,0>:q   {Compacted}
(W&f0.1) jmpi                                L2880
        mov (1|M0)               r41.0<1>:uq   r44.0<0;1,0>:uq                  {Compacted,@3,$30.src}
        mov (1|M0)               r32.0<1>:uq   r45.0<0;1,0>:uq                  {Compacted,@3,$0.src}
        mov (1|M0)               r43.0<1>:uq   r19.5<0;1,0>:uq                  {Compacted,$24.src}
        mov (1|M0)               r42.0<1>:uq   r19.6<0;1,0>:uq                  {Compacted,$28.src}
(W)     jmpi                                 L3040
        sync.nop                             null                             {$14.src}
        send.ugm (1|M0)          r99      r43  null:0  0x100000            0x0240F580           {I@3,$26} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r95      r42  null:0  0x100000            0x0240F580           {I@2,$27} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r87      r44  null:0  0x0            0x0240F580           {$25} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r91      r44  null:0  0x100000            0x0240F580           {$20} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r71      r45  null:0  0x0            0x0240F580           {$21} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r75      r45  null:0  0x100000            0x0240F580           {$22} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r41.0<1>:q    r41.0<0;1,0>:q    r19.3<0;1,0>:q   {Compacted,$30.src}
        add (1|M0)               r32.0<1>:q    r32.0<0;1,0>:q    r19.3<0;1,0>:q   {Compacted,$0.src}
        add (1|M0)               r43.0<1>:uq   r43.0<0;1,0>:uq   0x200:uw              {$26.src}
        add (1|M0)               r42.0<1>:uq   r42.0<0;1,0>:uq   0x200:uw              {$27.src}
        sync.allwr                           ($0,$14,$28,$29,$30,$31)
        dpas.8x8 (16|M0)         r122:d        r122:d            r55:s4            r63.0:b          {Atomic,$24.dst}
        dpas.8x8 (16|M0)         r106:d        r106:d            r55:s4            r67.0:b          {Atomic}
        dpas.8x8 (16|M0)         r154:d        r154:d            r55:s4            r79.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r138:d        r138:d            r55:s4            r83.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r130:d        r130:d            r59:s4            r63.0:b          {Atomic}
        dpas.8x8 (16|M0)         r114:d        r114:d            r59:s4            r67.0:b          {Atomic}
        dpas.8x8 (16|M0)         r162:d        r162:d            r59:s4            r79.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r146:d        r146:d            r59:s4            r83.0:ub         {$23}
(W&f0.1) jmpi                                L2480
