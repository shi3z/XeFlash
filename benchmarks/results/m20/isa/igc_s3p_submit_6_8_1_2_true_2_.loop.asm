        send.ugm (1|M0)          r95      r4  null:0  0x100000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {$8.src}
        send.ugm (1|M0)          r91      r1  null:0  0x0            0x0240F580           {I@1,$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r123     r2  null:0  0x0            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.allwr                           ($0,$1,$3,$5,$7,$8,$9,$11,$12,$15)
        dpas.8x8 (16|M0)         r44:d         r44:d             r56:u2            r77.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r28:d         r28:d             r56:u2            r65.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r36:d         r36:d             r58:u2            r81.0:b          {Atomic}
        dpas.8x8 (16|M0)         r18:d         r18:d             r58:u2            r73.0:ub         {$13}
        add (1|M0)               r3.0<1>:q     r1.0<0;1,0>:q     r17.1<0;1,0>:q   {Compacted}
        add (1|M0)               r6.0<1>:q     r2.0<0;1,0>:q     r17.1<0;1,0>:q   {Compacted}
        add (1|M0)               r1.3<1>:d     r1.3<0;1,0>:d     1:w               {$4.src}
        send.ugm (1|M0)          r113     r3  null:0  0x0            0x0240F580           {I@3,$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r103     r6  null:0  0x0            0x0240F580           {I@2,$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {Compacted,$10.dst}
        shr (16|M0)              acc0.0<1>:ud  r60.0<1;1,0>:ud   0x1:uw              {$14.dst}
        shl (16|M0)              r7.0<1>:d     r60.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r8.0<1>:d     r60.0<1;1,0>:d    2:w               {Compacted}
        add (1|M0)               r1.0<1>:q     r3.0<0;1,0>:q     r17.1<0;1,0>:q   {Compacted}
        add (1|M0)               r2.0<1>:q     r6.0<0;1,0>:q     r17.1<0;1,0>:q   {Compacted,$2.src}
        shl (16|M0)              r3.0<1>:d     r61.0<1;1,0>:d    1:w               {Compacted,$14.src}
        shl (16|M0)              r6.0<1>:d     r61.0<1;1,0>:d    2:w               {$15.src}
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r1.3<0;1,0>:ud    r1.2<0;1,0>:ud   {I@7}
        and (16|M0)              r12.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        shr (16|M0)              acc0.0<1>:ud  r61.0<1;1,0>:ud   0x1:uw
        and (16|M0)              r11.0<1>:d    r60.0<1;1,0>:d    1145324612:d
        and (16|M0)              r15.0<1>:d    r61.0<1;1,0>:d    1145324612:d
        and (16|M0)              r10.0<1>:d    r7.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r9.0<1>:d     r8.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r14.0<1>:d    r3.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r13.0<1>:d    r6.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r16.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        mov (16|M0)              r52.0<1>:f    r62.0<1;1,0>:f                   {Compacted}
        mov (16|M0)              r127.0<1>:f   r63.0<1;1,0>:f                   {Compacted}
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r44:d         r44:d             r9:u4             r77.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r28:d         r28:d             r9:u4             r65.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r36:d         r36:d             r13:u4            r81.0:b          {Atomic}
        dpas.8x8 (16|M0)         r18:d         r18:d             r13:u4            r73.0:ub         {$13}
(W&~f1.1) jmpi                               L3424
        sync.nop                             null                             {Compacted,$13.src}
        send.ugm (1|M0)          r77      r1  null:0  0x0            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r65      r2  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r1.0<1>:q     r1.0<0;1,0>:q     r17.1<0;1,0>:q   {Compacted,$7.src}
        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r17.1<0;1,0>:q   {$5.src}
        send.ugm (1|M0)          r56      r4  null:0  0x300000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r60      r4  null:0  0x500000            0x0240F580           {F@1,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x500]
        send.ugm (1|M0)          r81      r1  null:0  0x0            0x0240F580           {I@2,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r73      r2  null:0  0x0            0x0240F580           {I@1,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r4.0<1>:uq    r4.0<0;1,0>:uq    0x300:uw              {$10.src}
        add (1|M0)               r1.0<1>:q     r1.0<0;1,0>:q     r17.1<0;1,0>:q   {Compacted,$11.src}
        add (1|M0)               r2.0<1>:q     r2.0<0;1,0>:q     r17.1<0;1,0>:q   {Compacted,$12.src}
        sync.allwr                           ($2,$4,$13,$14,$15)
        dpas.8x8 (16|M0)         r44:d         r44:d             r95:u2            r91.0:b          {Atomic,$6.dst}
        dpas.8x8 (16|M0)         r28:d         r28:d             r95:u2            r123.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r36:d         r36:d             r97:u2            r113.0:b         {Atomic}
        dpas.8x8 (16|M0)         r18:d         r18:d             r97:u2            r103.0:ub        {$6}
        shl (16|M0)              r3.0<1>:d     r52.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r6.0<1>:d     r52.0<1;1,0>:d    2:w               {Compacted}
        shr (16|M0)              acc0.0<1>:ud  r52.0<1;1,0>:ud   0x1:uw
        shl (16|M0)              r11.0<1>:d    r127.0<1;1,0>:d   1:w               {Compacted}
        shl (16|M0)              r12.0<1>:d    r127.0<1;1,0>:d   2:w               {Compacted}
        cmp (1|M0)    (eq)f1.0   null<1>:d     r1.3<0;1,0>:d     r1.2<0;1,0>:d
        and (16|M0)              r10.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        shr (16|M0)              acc0.0<1>:ud  r127.0<1;1,0>:ud  0x1:uw
        and (16|M0)              r9.0<1>:ud    r52.0<1;1,0>:ud   0x44444444:ud
        and (16|M0)              r15.0<1>:ud   r127.0<1;1,0>:ud  0x44444444:ud
        and (16|M0)              r8.0<1>:d     r3.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r7.0<1>:d     r6.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r14.0<1>:d    r11.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r13.0<1>:d    r12.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r16.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r44:d         r44:d             r7:u4             r91.0:b          {Atomic,$6.dst}
        dpas.8x8 (16|M0)         r28:d         r28:d             r7:u4             r123.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r36:d         r36:d             r13:u4            r113.0:b         {Atomic}
        dpas.8x8 (16|M0)         r18:d         r18:d             r13:u4            r103.0:ub        {$4}
(W&f1.0) jmpi                                L3952
(W)     jmpi                                 L2704
