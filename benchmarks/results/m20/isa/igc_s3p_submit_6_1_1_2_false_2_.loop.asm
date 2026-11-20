        add (1|M0)               r3.0<1>:q     r124.0<0;1,0>:q   r126.1<0;1,0>:q  {Compacted,I@3}
        send.ugm (1|M0)          r115     r29  null:0  0x100000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {Compacted,$9.src}
        send.ugm (1|M0)          r111     r3  null:0  0x0            0x0210C580           {I@1,$13} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r28.1<1>:d    r28.1<0;1,0>:d    1:w
        sync.nop                             null                             {F@1}
        sync.allwr                           ($4,$8,$10,$11)
        dpas.8x1 (16|M0)         r32:d         r32:d             r34:u2            r123.0:b         {$2}
        sync.allwr                           ($6,$9)
        dpas.8x1 (16|M0)         r38:d         r38:d             r36:u2            r125.0:b         {$5}
        sync.nop                             null                             {Compacted,$7.dst}
        shl (16|M0)              r6.0<1>:d     r119.0<1;1,0>:d   2:w               {Compacted,$3.dst}
        shl (16|M0)              r11.0<1>:d    r119.0<1;1,0>:d   1:w               {Compacted}
        shr (16|M0)              acc0.0<1>:ud  r119.0<1;1,0>:ud  0x1:uw
        shl (16|M0)              r12.0<1>:d    r120.0<1;1,0>:d   2:w               {Compacted}
        shl (16|M0)              r17.0<1>:d    r120.0<1;1,0>:d   1:w
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r28.1<0;1,0>:ud   r28.0<0;1,0>:ud  {I@6}
        and (16|M0)              r10.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        shr (16|M0)              acc0.0<1>:ud  r120.0<1;1,0>:ud  0x1:uw
        and (16|M0)              r9.0<1>:d     r119.0<1;1,0>:d   1145324612:d
        and (16|M0)              r15.0<1>:d    r120.0<1;1,0>:d   1145324612:d
        and (16|M0)              r7.0<1>:d     r6.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r8.0<1>:d     r11.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r13.0<1>:d    r12.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r14.0<1>:d    r17.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r16.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        mov (16|M0)              r30.0<1>:f    r121.0<1;1,0>:f                  {Compacted}
        mov (16|M0)              r114.0<1>:f   r122.0<1;1,0>:f                  {Compacted}
        sync.nop                             null                             {Compacted,I@4}
        dpas.8x1 (16|M0)         r32:d         r32:d             r7:u4             r123.0:b         {$2}
        sync.nop                             null                             {Compacted,I@1}
        dpas.8x1 (16|M0)         r38:d         r38:d             r13:u4            r125.0:b         {$5}
        send.ugm (1|M0)          r113     r124  null:0  0x0            0x0210C580           {$14} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r124.0<1>:q   r3.0<0;1,0>:q     r126.1<0;1,0>:q  {Compacted,$14.src}
(W&~f1.1) jmpi                               L2096
        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r123     r124  null:0  0x0            0x0210C580           {I@2,$10} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r124.0<1>:q   r124.0<0;1,0>:q   r126.1<0;1,0>:q  {Compacted,$10.src}
        send.ugm (1|M0)          r34      r29  null:0  0x300000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r119     r29  null:0  0x500000            0x0240F580           {F@1,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x500]
        sync.nop                             null                             {Compacted,$5.src}
        send.ugm (1|M0)          r125     r124  null:0  0x0            0x0210C580           {I@1,$6} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r29.0<1>:uq   r29.0<0;1,0>:uq   0x300:uw              {$7.src}
        add (1|M0)               r124.0<1>:q   r124.0<0;1,0>:q   r126.1<0;1,0>:q  {$6.src}
        sync.allwr                           ($2,$14)
        dpas.8x1 (16|M0)         r32:d         r32:d             r115:u2           r113.0:b         {$12}
        sync.nop                             null                             {Compacted,$5.dst}
        dpas.8x1 (16|M0)         r38:d         r38:d             r117:u2           r111.0:b         {$13}
        shl (16|M0)              r3.0<1>:d     r30.0<1;1,0>:d    2:w               {Compacted}
        shl (16|M0)              r10.0<1>:d    r30.0<1;1,0>:d    1:w
        and (16|M0)              r8.0<1>:d     r30.0<1;1,0>:d    1145324612:d
        shl (16|M0)              r11.0<1>:d    r114.0<1;1,0>:d   2:w               {Compacted}
        shl (16|M0)              r16.0<1>:d    r114.0<1;1,0>:d   1:w               {Compacted}
        and (16|M0)              r14.0<1>:d    r114.0<1;1,0>:d   1145324612:d
        shr (16|M0)              r30.0<1>:ud   r30.0<1;1,0>:ud   0x1:uw              {Compacted}
        shr (16|M0)              r114.0<1>:ud  r114.0<1;1,0>:ud  0x1:uw              {Compacted}
        cmp (1|M0)    (eq)f1.0   null<1>:d     r28.1<0;1,0>:d    r28.0<0;1,0>:d
        and (16|M0)              r6.0<1>:d     r3.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r7.0<1>:d     r10.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r12.0<1>:d    r11.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r13.0<1>:d    r16.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r9.0<1>:ud    r30.0<1;1,0>:ud   0x44444444:ud              {I@7}
        and (16|M0)              r15.0<1>:ud   r114.0<1;1,0>:ud  0x44444444:ud              {I@7}
        sync.nop                             null                             {Compacted,I@2}
        sync.nop                             null                             {Compacted,$12.dst}
        dpas.8x1 (16|M0)         r32:d         r32:d             r6:u4             r113.0:b         {$8}
        sync.nop                             null                             {Compacted,I@1}
        sync.nop                             null                             {Compacted,$13.dst}
        dpas.8x1 (16|M0)         r38:d         r38:d             r12:u4            r111.0:b         {$9}
(W&f1.0) jmpi                                L2456
(W)     jmpi                                 L1504
