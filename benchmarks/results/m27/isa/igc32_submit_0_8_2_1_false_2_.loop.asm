        add (1|M0)               r3.0<1>:q     r47.0<0;1,0>:q    r20.2<0;1,0>:q   {Compacted,I@5}
        sync.nop                             null                             {Compacted,$8.src}
        add (1|M0)               r47.0<1>:q    r47.0<0;1,0>:q    r20.3<0;1,0>:q   {Compacted,@5,$6.src}
        sync.nop                             null                             {$9.src}
        send.ugm (1|M0)          r6       r33  null:0  0x0            0x0240F580           {I@5,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r3  null:0  0x0            0x0240F580           {I@2,$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r15      r3  null:0  0x100000            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($2,$6,$7,$8,$9,$10,$11)
        dpas.8x8 (16|M0)         r56:d         r56:d             r43:s4            r35.0:b          {Atomic,$5.dst}
        dpas.8x8 (16|M0)         r48:d         r48:d             r43:s4            r39.0:b          {$5}
        sync.nop                             null                             {$5.src}
        send.ugm (1|M0)          r43      r34  null:0  0x200000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r35      r47  null:0  0x0            0x0240F580           {I@1,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r39      r47  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r20.1<1>:d    r20.1<0;1,0>:d    2:w
        add (1|M0)               r20.4<1>:q    r34.0<0;1,0>:q    512:w
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r20.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@2}
        add (1|M0)               r33.0<1>:uq   r34.0<0;1,0>:uq   0x300:uw              {$12.src}
        sync.allwr                           ($5,$13,$14)
        dpas.8x8 (16|M0)         r56:d         r56:d             r6:s4             r11.0:b          {Atomic,$12.dst}
        dpas.8x8 (16|M0)         r48:d         r48:d             r6:s4             r15.0:b          {$9}
(W&~f1.0) jmpi                               L2016
        mov (1|M0)               r34.0<1>:uq   r20.4<0;1,0>:uq                  {@4,$10.src}
(W)     jmpi                                 L1656
