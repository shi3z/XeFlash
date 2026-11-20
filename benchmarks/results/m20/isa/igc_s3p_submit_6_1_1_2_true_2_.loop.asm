        send.ugm (1|M0)          r30      r118  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {Compacted,$14.src}
        send.ugm (1|M0)          r103     r25  null:0  0x0            0x0210C580           {$7} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r101     r120  null:0  0x0            0x0210C580           {$6} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r3.0<1>:q     r25.0<0;1,0>:q    r18.1<0;1,0>:q   {Compacted}
        add (1|M0)               r6.0<1>:q     r120.0<0;1,0>:q   r18.1<0;1,0>:q   {Compacted,$5.src}
        add (1|M0)               r18.4<1>:d    r18.4<0;1,0>:d    1:w               {I@3}
        sync.allwr                           ($2,$4,$9,$13,$14)
        dpas.8x1 (16|M0)         r48:d         r48:d             r105:u2           r113.0:b         {$15}
        sync.allwr                           ($5,$10)
        dpas.8x1 (16|M0)         r44:d         r44:d             r105:u2           r109.0:ub        {Compacted,$0}
        sync.nop                             null                             {Compacted,$11.dst}
        dpas.8x1 (16|M0)         r42:d         r42:d             r107:u2           r115.0:b         {$1}
        sync.nop                             null                             {Compacted,$12.dst}
        dpas.8x1 (16|M0)         r36:d         r36:d             r107:u2           r111.0:ub        {Compacted,$3}
        send.ugm (1|M0)          r99      r3  null:0  0x0            0x0210C580           {I@3,$14} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r97      r6  null:0  0x0            0x0210C580           {I@2,$2} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        shl (16|M0)              r7.0<1>:d     r26.0<1;1,0>:d    2:w               {Compacted}
        shl (16|M0)              r12.0<1>:d    r26.0<1;1,0>:d    1:w               {Compacted}
        shr (16|M0)              acc0.0<1>:ud  r26.0<1;1,0>:ud   0x1:uw
        add (1|M0)               r25.0<1>:q    r3.0<0;1,0>:q     r18.1<0;1,0>:q   {Compacted,$7.src}
        add (1|M0)               r120.0<1>:q   r6.0<0;1,0>:q     r18.1<0;1,0>:q   {Compacted,$6.src}
        shl (16|M0)              r3.0<1>:d     r27.0<1;1,0>:d    2:w               {Compacted,$14.src}
        shl (16|M0)              r6.0<1>:d     r27.0<1;1,0>:d    1:w               {Compacted,$2.src}
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r18.4<0;1,0>:ud   r126.1<0;1,0>:ud {I@7}
        and (16|M0)              r11.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        shr (16|M0)              acc0.0<1>:ud  r27.0<1;1,0>:ud   0x1:uw
        and (16|M0)              r10.0<1>:d    r26.0<1;1,0>:d    1145324612:d
        and (16|M0)              r15.0<1>:d    r27.0<1;1,0>:d    1145324612:d
        and (16|M0)              r8.0<1>:d     r7.0<1;1,0>:d     1145324612:d
        and (16|M0)              r9.0<1>:d     r12.0<1;1,0>:d    1145324612:d
        and (16|M0)              r13.0<1>:d    r3.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r14.0<1>:d    r6.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r16.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        mov (16|M0)              r34.0<1>:f    r28.0<1;1,0>:f                   {Compacted}
        mov (16|M0)              r116.0<1>:f   r29.0<1;1,0>:f                   {Compacted}
        sync.nop                             null                             {Compacted,I@4}
        dpas.8x1 (16|M0)         r48:d         r48:d             r8:u4             r113.0:b         {$15}
        dpas.8x1 (16|M0)         r44:d         r44:d             r8:u4             r109.0:ub        {Compacted,$0}
        sync.nop                             null                             {Compacted,I@1}
        dpas.8x1 (16|M0)         r42:d         r42:d             r13:u4            r115.0:b         {$1}
        dpas.8x1 (16|M0)         r36:d         r36:d             r13:u4            r111.0:ub        {Compacted,$3}
(W&~f1.1) jmpi                               L3400
        sync.nop                             null                             {Compacted,$15.src}
        send.ugm (1|M0)          r113     r25  null:0  0x0            0x0210C580           {$9} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {Compacted,$0.src}
        send.ugm (1|M0)          r109     r120  null:0  0x0            0x0210C580           {$10} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r25.0<1>:q    r25.0<0;1,0>:q    r18.1<0;1,0>:q   {Compacted,$9.src}
        add (1|M0)               r120.0<1>:q   r120.0<0;1,0>:q   r18.1<0;1,0>:q   {Compacted,$10.src}
        send.ugm (1|M0)          r105     r118  null:0  0x300000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r26      r118  null:0  0x500000            0x0240F580           {F@1,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x500]
        sync.nop                             null                             {$1.src}
        send.ugm (1|M0)          r115     r25  null:0  0x0            0x0210C580           {I@2,$7} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {Compacted,$3.src}
        send.ugm (1|M0)          r111     r120  null:0  0x0            0x0210C580           {I@1,$13} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r118.0<1>:uq  r118.0<0;1,0>:uq  0x300:uw              {$6.src}
        add (1|M0)               r25.0<1>:q    r25.0<0;1,0>:q    r18.1<0;1,0>:q   {Compacted,$7.src}
        add (1|M0)               r120.0<1>:q   r120.0<0;1,0>:q   r18.1<0;1,0>:q   {Compacted,$13.src}
        shl (16|M0)              r3.0<1>:d     r34.0<1;1,0>:d    2:w               {Compacted}
        sync.allwr                           ($7,$8)
        dpas.8x1 (16|M0)         r48:d         r48:d             r30:u2            r103.0:b         {$15}
        sync.nop                             null                             {Compacted,$6.dst}
        dpas.8x1 (16|M0)         r44:d         r44:d             r30:u2            r101.0:ub        {Compacted,$0}
        sync.nop                             null                             {Compacted,$1.dst}
        dpas.8x1 (16|M0)         r42:d         r42:d             r32:u2            r99.0:b          {$14}
        sync.nop                             null                             {Compacted,$3.dst}
        dpas.8x1 (16|M0)         r36:d         r36:d             r32:u2            r97.0:ub         {Compacted,$2}
        shl (16|M0)              r10.0<1>:d    r34.0<1;1,0>:d    1:w               {Compacted}
        and (16|M0)              r8.0<1>:d     r34.0<1;1,0>:d    1145324612:d
        shl (16|M0)              r11.0<1>:d    r116.0<1;1,0>:d   2:w               {Compacted}
        and (16|M0)              r14.0<1>:d    r116.0<1;1,0>:d   1145324612:d
        and (16|M0)              r6.0<1>:d     r3.0<1;1,0>:d     1145324612:d               {I@5}
        shr (16|M0)              r34.0<1>:ud   r34.0<1;1,0>:ud   0x1:uw              {Compacted}
        shl (16|M0)              r3.0<1>:d     r116.0<1;1,0>:d   1:w               {Compacted}
        shr (16|M0)              r116.0<1>:ud  r116.0<1;1,0>:ud  0x1:uw              {Compacted}
        cmp (1|M0)    (eq)f1.0   null<1>:d     r18.4<0;1,0>:d    r126.1<0;1,0>:d
        and (16|M0)              r7.0<1>:d     r10.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r12.0<1>:d    r11.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r9.0<1>:ud    r34.0<1;1,0>:ud   0x44444444:ud              {I@6}
        and (16|M0)              r13.0<1>:d    r3.0<1;1,0>:d     1145324612:d               {I@6}
        and (16|M0)              r15.0<1>:ud   r116.0<1;1,0>:ud  0x44444444:ud              {I@6}
        sync.nop                             null                             {Compacted,I@3}
        sync.nop                             null                             {Compacted,$15.dst}
        dpas.8x1 (16|M0)         r48:d         r48:d             r6:u4             r103.0:b         {$14}
        sync.nop                             null                             {Compacted,$0.dst}
        dpas.8x1 (16|M0)         r44:d         r44:d             r6:u4             r101.0:ub        {Compacted,$2}
        sync.nop                             null                             {Compacted,I@1}
        sync.nop                             null                             {Compacted,$14.dst}
        dpas.8x1 (16|M0)         r42:d         r42:d             r12:u4            r99.0:b          {$5}
        sync.nop                             null                             {Compacted,$2.dst}
        dpas.8x1 (16|M0)         r36:d         r36:d             r12:u4            r97.0:ub         {Compacted,$11}
(W&f1.0) jmpi                                L3840
(W)     jmpi                                 L2672
