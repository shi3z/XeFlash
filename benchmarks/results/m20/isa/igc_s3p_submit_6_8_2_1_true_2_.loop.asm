        sync.allrd                           ($5,$12)
        send.ugm (1|M0)          r7       r23  null:0  0x0            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r23  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r15      r24  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r19      r24  null:0  0x100000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($0,$1,$3,$6,$8,$10,$11,$12,$13)
        dpas.8x8 (16|M0)         r36:d         r36:d             r90:u2            r45.0:b          {Atomic,$14.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r90:u2            r113.0:b         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r90:u2            r109.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r82:d         r82:d             r90:u2            r99.0:ub         {$14}
        add (1|M0)               r3.0<1>:q     r23.0<0;1,0>:q    r4.0<0;1,0>:q    {Compacted}
        add (1|M0)               r6.0<1>:q     r24.0<0;1,0>:q    r4.0<0;1,0>:q    {Compacted}
        sync.nop                             null                             {Compacted,$9.dst}
        sync.nop                             null                             {Compacted,$5.src}
        shl (16|M0)              r23.0<1>:d    r94.0<1;1,0>:d    1:w               {Compacted,$15.dst}
        shl (16|M0)              r24.0<1>:d    r94.0<1;1,0>:d    2:w               {Compacted,$2.src}
        shr (16|M0)              acc0.0<1>:ud  r94.0<1;1,0>:ud   0x1:uw
        and (16|M0)              r27.0<1>:d    r94.0<1;1,0>:d    1145324612:d
        and (16|M0)              r26.0<1>:d    r23.0<1;1,0>:d    1145324612:d               {I@4}
        and (16|M0)              r25.0<1>:d    r24.0<1;1,0>:d    1145324612:d               {I@4}
        and (16|M0)              r28.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        send.ugm (1|M0)          r58      r1  null:0  0x100000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r36:d         r36:d             r25:u4            r45.0:b          {$14}
        sync.nop                             null                             {Compacted,$14.src}
        send.ugm (1|M0)          r45      r3  null:0  0x0            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        dpas.8x8 (16|M0)         r50:d         r50:d             r25:u4            r113.0:b         {$6}
        sync.nop                             null                             {Compacted,$6.src}
        send.ugm (1|M0)          r113     r3  null:0  0x100000            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        dpas.8x8 (16|M0)         r66:d         r66:d             r25:u4            r109.0:ub        {$10}
        sync.nop                             null                             {$10.src}
        send.ugm (1|M0)          r109     r6  null:0  0x0            0x0240F580           {$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        dpas.8x8 (16|M0)         r82:d         r82:d             r25:u4            r99.0:ub         {$12}
        sync.nop                             null                             {Compacted,$12.src}
        send.ugm (1|M0)          r99      r6  null:0  0x100000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        shl (16|M0)              r25.0<1>:d    r95.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r26.0<1>:d    r95.0<1;1,0>:d    2:w
        shr (16|M0)              acc0.0<1>:ud  r95.0<1;1,0>:ud   0x1:uw
        and (16|M0)              r29.0<1>:d    r95.0<1;1,0>:d    1145324612:d
        and (16|M0)              r28.0<1>:d    r25.0<1;1,0>:d    1145324612:d               {I@4}
        sync.allwr                           ($2,$4,$5,$6,$10,$12,$14)
        dpas.8x8 (16|M0)         r36:d         r36:d             r92:u2            r7.0:b           {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r92:u2            r11.0:b          {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r92:u2            r15.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r82:d         r82:d             r92:u2            r19.0:ub         {$7}
        and (16|M0)              r27.0<1>:d    r26.0<1;1,0>:d    1145324612:d               {I@4}
        and (16|M0)              r30.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r36:d         r36:d             r27:u4            r7.0:b           {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r27:u4            r11.0:b          {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r27:u4            r15.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r82:d         r82:d             r27:u4            r19.0:ub         {$7}
        add (1|M0)               r1.2<1>:d     r1.2<0;1,0>:d     1:w               {$9.src}
        add (1|M0)               r23.0<1>:q    r3.0<0;1,0>:q     r4.0<0;1,0>:q    {Compacted}
        add (1|M0)               r24.0<1>:q    r6.0<0;1,0>:q     r4.0<0;1,0>:q    {Compacted}
        shl (16|M0)              r3.0<1>:d     r96.0<1;1,0>:d    1:w               {Compacted,$13.src}
        shl (16|M0)              r6.0<1>:d     r96.0<1;1,0>:d    2:w               {Compacted,$0.src}
        shr (16|M0)              acc0.0<1>:ud  r96.0<1;1,0>:ud   0x1:uw
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r1.2<0;1,0>:ud    r4.2<0;1,0>:ud   {I@6}
        sync.allwr                           ($7,$11)
        dpas.8x8 (16|M0)         r36:d         r36:d             r58:u2            r45.0:b          {$9}
        and (16|M0)              r9.0<1>:d     r96.0<1;1,0>:d    1145324612:d
        sync.nop                             null                             {$15.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r58:u2            r113.0:b         {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r58:u2            r109.0:ub        {$13}
        and (16|M0)              r8.0<1>:d     r3.0<1;1,0>:d     1145324612:d               {I@5}
        dpas.8x8 (16|M0)         r82:d         r82:d             r58:u2            r99.0:ub         {$0}
        and (16|M0)              r7.0<1>:d     r6.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r10.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        mov (16|M0)              r74.0<1>:f    r97.0<1;1,0>:f                   {Compacted}
        sync.nop                             null                             {Compacted,I@1}
        sync.allwr                           ($0,$13)
        dpas.8x8 (16|M0)         r36:d         r36:d             r7:u4             r45.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r7:u4             r113.0:b         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r7:u4             r109.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r82:d         r82:d             r7:u4             r99.0:ub         {$9}
        send.ugm (1|M0)          r15      r23  null:0  0x0            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r23  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r123     r24  null:0  0x0            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r75      r24  null:0  0x100000            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r23.0<1>:q    r23.0<0;1,0>:q    r4.0<0;1,0>:q    {Compacted,$8.src}
        add (1|M0)               r24.0<1>:q    r24.0<0;1,0>:q    r4.0<0;1,0>:q    {Compacted,$14.src}
(W&~f1.1) jmpi                               L4528
        send.ugm (1|M0)          r90      r1  null:0  0x300000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        send.ugm (1|M0)          r94      r1  null:0  0x500000            0x0240F580           {F@1,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x500]
        sync.nop                             null                             {$9.src}
        send.ugm (1|M0)          r45      r23  null:0  0x0            0x0240F580           {I@3,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r113     r23  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r109     r24  null:0  0x0            0x0240F580           {I@2,$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r99      r24  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r1.0<1>:uq    r1.0<0;1,0>:uq    0x300:uw
        add (1|M0)               r23.0<1>:q    r23.0<0;1,0>:q    r4.0<0;1,0>:q    {Compacted,$11.src}
        add (1|M0)               r24.0<1>:q    r24.0<0;1,0>:q    r4.0<0;1,0>:q    {Compacted,$4.src}
        sync.allwr                           ($1,$3,$8,$14)
        dpas.8x8 (16|M0)         r36:d         r36:d             r60:u2            r15.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r60:u2            r11.0:b          {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r60:u2            r123.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r82:d         r82:d             r60:u2            r75.0:ub         {$9}
        shl (16|M0)              r3.0<1>:d     r74.0<1;1,0>:d    1:w               {Compacted}
        shl (16|M0)              r6.0<1>:d     r74.0<1;1,0>:d    2:w               {Compacted}
        shr (16|M0)              acc0.0<1>:ud  r74.0<1;1,0>:ud   0x1:uw
        cmp (1|M0)    (eq)f1.0   null<1>:d     r1.2<0;1,0>:d     r4.2<0;1,0>:d
        and (16|M0)              r9.0<1>:ud    r74.0<1;1,0>:ud   0x44444444:ud
        and (16|M0)              r8.0<1>:d     r3.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r7.0<1>:d     r6.0<1;1,0>:d     1145324612:d               {I@5}
        and (16|M0)              r10.0<1>:ud   acc0.0<1;1,0>:ud  0x44444444:ud
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r36:d         r36:d             r7:u4             r15.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r7:u4             r11.0:b          {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r7:u4             r123.0:ub        {Atomic}
        dpas.8x8 (16|M0)         r82:d         r82:d             r7:u4             r75.0:ub         {$5}
(W&f1.0) jmpi                                L4960
(W)     jmpi                                 L3200
