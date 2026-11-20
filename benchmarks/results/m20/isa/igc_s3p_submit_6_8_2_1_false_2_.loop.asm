        sync.nop                             null                             {$10.src}
        send.ugm (1|M0)          r7       r26  null:0  0x0            0x0240F580           {I@4,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r26  null:0  0x100000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($4,$5,$6,$7,$8,$10)
        dpas.8x8 (16|M0)         r74:d         r74:d             r48:u2            r27.0:b          {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r48:u2            r35.0:b          {$2}
        sync.nop                             null                             {Compacted,$9.dst}
        shl (16|M0)              r6.0<1>:d     r39.0<1;1,0>:d    1:w               {Compacted,$3.dst}
        shl (16|M0)              r15.0<1>:d    r39.0<1;1,0>:d    2:w               {Compacted}
        shr (16|M0)              acc0.0<1>:ud  r39.0<1;1,0>:ud   0x1:uw
        add (1|M0)               r3.0<1>:q     r26.0<0;1,0>:q    r25.2<0;1,0>:q   {Compacted,I@5}
        and (16|M0)              r18.0<1>:d    r39.0<1;1,0>:d    1145324612:d
        and (16|M0)              r17.0<1>:d    r6.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r16.0<1>:d    r15.0<1;1,0>:d    1145324612:d               {I@5}
        and (16|M0)              r19.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        send.ugm (1|M0)          r54      r31  null:0  0x100000            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r74:d         r74:d             r16:u4            r27.0:b          {$2}
        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r27      r3  null:0  0x0            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        dpas.8x8 (16|M0)         r66:d         r66:d             r16:u4            r35.0:b          {$15}
        sync.nop                             null                             {Compacted,$15.src}
        send.ugm (1|M0)          r35      r3  null:0  0x100000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r5.0<1>:q     r3.0<0;1,0>:q     r25.2<0;1,0>:q   {Compacted}
        shl (16|M0)              r6.0<1>:d     r40.0<1;1,0>:d    1:w               {Compacted}
        send.ugm (1|M0)          r43      r5  null:0  0x0            0x0240F580           {I@2,$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r59      r5  null:0  0x100000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        shl (16|M0)              r15.0<1>:d    r40.0<1;1,0>:d    2:w
        shr (16|M0)              acc0.0<1>:ud  r40.0<1;1,0>:ud   0x1:uw
        and (16|M0)              r22.0<1>:d    r40.0<1;1,0>:d    1145324612:d
        and (16|M0)              r21.0<1>:d    r6.0<1;1,0>:d     1145324612:d               {I@4}
        and (16|M0)              r20.0<1>:d    r15.0<1;1,0>:d    1145324612:d               {I@4}
        and (16|M0)              r23.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        add (1|M0)               r25.6<1>:d    r25.6<0;1,0>:d    1:w
        shl (16|M0)              r3.0<1>:d     r41.0<1;1,0>:d    1:w               {Compacted,$0.src}
        shl (16|M0)              r6.0<1>:d     r41.0<1;1,0>:d    2:w               {Compacted}
        sync.allwr                           ($2,$12,$15)
        dpas.8x8 (16|M0)         r74:d         r74:d             r50:u2            r7.0:b           {Atomic,$11.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r50:u2            r11.0:b          {$11}
        shr (16|M0)              acc0.0<1>:ud  r41.0<1;1,0>:ud   0x1:uw
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r25.6<0;1,0>:ud   r25.1<0;1,0>:ud  {I@4}
        and (16|M0)              r17.0<1>:d    r41.0<1;1,0>:d    1145324612:d
        dpas.8x8 (16|M0)         r74:d         r74:d             r20:u4            r7.0:b           {Atomic,$11.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r20:u4            r11.0:b          {$11}
        and (16|M0)              r16.0<1>:d    r3.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r15.0<1>:d    r6.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r18.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        mov (16|M0)              r32.0<1>:f    r42.0<1;1,0>:f                   {Compacted}
        add (1|M0)               r26.0<1>:q    r5.0<0;1,0>:q     r25.2<0;1,0>:q   {Compacted}
        sync.allwr                           ($0,$11,$14)
        dpas.8x8 (16|M0)         r74:d         r74:d             r54:u2            r27.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r54:u2            r35.0:b          {$13}
        sync.nop                             null                             {I@2}
        dpas.8x8 (16|M0)         r74:d         r74:d             r15:u4            r27.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r15:u4            r35.0:b          {$13}
(W&~f1.1) jmpi                               L2528
        send.ugm (1|M0)          r48      r31  null:0  0x300000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r39      r31  null:0  0x500000            0x0240F580           {F@1,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x500]
        sync.nop                             null                             {$13.src}
        send.ugm (1|M0)          r27      r26  null:0  0x0            0x0240F580           {I@2,$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r35      r26  null:0  0x100000            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r31.0<1>:uq   r31.0<0;1,0>:uq   0x300:uw              {$9.src}
        add (1|M0)               r26.0<1>:q    r26.0<0;1,0>:q    r25.2<0;1,0>:q   {$7.src}
        sync.allwr                           ($10,$13)
        dpas.8x8 (16|M0)         r74:d         r74:d             r56:u2            r43.0:b          {Atomic,$1.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r56:u2            r59.0:b          {$1}
        shl (16|M0)              r3.0<1>:d     r32.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r6.0<1>:d     r32.0<1;1,0>:d    2:w               {Compacted}
        shr (16|M0)              acc0.0<1>:ud  r32.0<1;1,0>:ud   0x1:uw
        cmp (1|M0)    (eq)f1.0   null<1>:d     r25.6<0;1,0>:d    r25.1<0;1,0>:d
        and (16|M0)              r9.0<1>:ud    r32.0<1;1,0>:ud   0x44444444:ud
        and (16|M0)              r8.0<1>:d     r3.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r7.0<1>:d     r6.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r10.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r74:d         r74:d             r7:u4             r43.0:b          {Atomic,$1.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r7:u4             r59.0:b          {$10}
(W&~f1.0) jmpi                               L1616
