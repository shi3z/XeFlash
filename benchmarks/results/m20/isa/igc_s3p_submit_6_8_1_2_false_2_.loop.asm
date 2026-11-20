        send.ugm (1|M0)          r39      r25  null:0  0x100000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {$7.src}
        send.ugm (1|M0)          r43      r20  null:0  0x0            0x0240F580           {I@3,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.allwr                           ($4,$5,$7,$8,$9,$11)
        dpas.8x8 (16|M0)         r58:d         r58:d             r35:u2            r27.0:b          {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r72:d         r72:d             r37:u2            r21.0:b          {$2}
        add (1|M0)               r3.0<1>:q     r20.0<0;1,0>:q    r19.2<0;1,0>:q   {Compacted}
        add (1|M0)               r19.6<1>:d    r19.6<0;1,0>:d    1:w               {I@2}
        send.ugm (1|M0)          r49      r3  null:0  0x0            0x0240F580           {I@2,$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {Compacted,$6.dst}
        shr (16|M0)              acc0.0<1>:ud  r31.0<1;1,0>:ud   0x1:uw              {$3.dst}
        shl (16|M0)              r6.0<1>:d     r31.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r7.0<1>:d     r31.0<1;1,0>:d    2:w               {Compacted}
        shl (16|M0)              r12.0<1>:d    r32.0<1;1,0>:d    1:w               {Compacted}
        add (1|M0)               r20.0<1>:q    r3.0<0;1,0>:q     r19.2<0;1,0>:q   {Compacted,$12.src}
        shl (16|M0)              r3.0<1>:d     r32.0<1;1,0>:d    2:w               {$13.src}
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r19.6<0;1,0>:ud   r19.1<0;1,0>:ud  {I@7}
        and (16|M0)              r11.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        shr (16|M0)              acc0.0<1>:ud  r32.0<1;1,0>:ud   0x1:uw
        and (16|M0)              r10.0<1>:d    r31.0<1;1,0>:d    1145324612:d
        and (16|M0)              r15.0<1>:d    r32.0<1;1,0>:d    1145324612:d
        and (16|M0)              r9.0<1>:d     r6.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r8.0<1>:d     r7.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r14.0<1>:d    r12.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r13.0<1>:d    r3.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r16.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        mov (16|M0)              r26.0<1>:f    r33.0<1;1,0>:f                   {Compacted}
        mov (16|M0)              r47.0<1>:f    r34.0<1;1,0>:f                   {Compacted}
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r58:d         r58:d             r8:u4             r27.0:b          {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r72:d         r72:d             r13:u4            r21.0:b          {$2}
(W&~f1.1) jmpi                               L2184
        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r27      r20  null:0  0x0            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r20.0<1>:q    r20.0<0;1,0>:q    r19.2<0;1,0>:q   {Compacted,$8.src}
        send.ugm (1|M0)          r35      r25  null:0  0x300000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r31      r25  null:0  0x500000            0x0240F580           {F@1,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x500]
        send.ugm (1|M0)          r21      r20  null:0  0x0            0x0240F580           {I@1,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r25.0<1>:uq   r25.0<0;1,0>:uq   0x300:uw              {$6.src}
        add (1|M0)               r20.0<1>:q    r20.0<0;1,0>:q    r19.2<0;1,0>:q   {Compacted,$11.src}
        sync.allwr                           ($2,$12,$13)
        dpas.8x8 (16|M0)         r58:d         r58:d             r39:u2            r43.0:b          {Atomic,$10.dst}
        dpas.8x8 (16|M0)         r72:d         r72:d             r41:u2            r49.0:b          {$10}
        shl (16|M0)              r3.0<1>:d     r26.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r6.0<1>:d     r26.0<1;1,0>:d    2:w               {Compacted}
        shr (16|M0)              acc0.0<1>:ud  r26.0<1;1,0>:ud   0x1:uw
        shl (16|M0)              r11.0<1>:d    r47.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r12.0<1>:d    r47.0<1;1,0>:d    2:w
        cmp (1|M0)    (eq)f1.0   null<1>:d     r19.6<0;1,0>:d    r19.1<0;1,0>:d
        and (16|M0)              r10.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        shr (16|M0)              acc0.0<1>:ud  r47.0<1;1,0>:ud   0x1:uw
        and (16|M0)              r9.0<1>:ud    r26.0<1;1,0>:ud   0x44444444:ud
        and (16|M0)              r15.0<1>:ud   r47.0<1;1,0>:ud   0x44444444:ud
        and (16|M0)              r8.0<1>:d     r3.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r7.0<1>:d     r6.0<1;1,0>:d     1145324612:d               {I@7}
        and (16|M0)              r14.0<1>:d    r11.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r13.0<1>:d    r12.0<1;1,0>:d    1145324612:d               {I@7}
        and (16|M0)              r16.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r58:d         r58:d             r7:u4             r43.0:b          {Atomic,$10.dst}
        dpas.8x8 (16|M0)         r72:d         r72:d             r13:u4            r49.0:b          {$7}
(W&~f1.0) jmpi                               L1632
