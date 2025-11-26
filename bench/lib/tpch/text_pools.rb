# frozen_string_literal: true

module Tpch
  module TextPools
    SYLLABLES = %w[
      aa af al ar as at be bj bl br by ce ch cl co cu da dd de di dj dk
      dm do dr du dv dy ed ef eg eh el em en er es et ev ex ey fa fe fi
      fl fr ga ge gi go gu ha he hi ho hu hy id if ig ih ij il im in io
      ip iq ir is it iv ix ja je ji jo ju ka ke ki kj kl km kn ko kr ku
      ky la le li ll lo lr ls lt lu lv ma me mi mm mn mo mr ms mt mu mv
      my na ne ng ni no np ns nt nu nv ny od oe of og oh oi ok ol om on
      oo op oq or os ot ou ov ow ox oy pa pe pi po pp pr ps pt pu py ra
      re rg rh ri rj rk rl rm rn ro rp rq rr rs rt ru rv rw rx ry sa se
      sh si sk sl sm sn so sp sq sr ss st su sv sy ta te ti tj tk tl tm
      tn to tp tq tr ts tt tu tv tw tx ty ug uh ui um un up ur us ut va
      ve vi vo vu wa we wi wo wv wv xa xe xi xo xu xx xy ya ye yi yo yu
      za ze zi zl zo zr zs zv zx zy
    ].freeze

    MKT_SEGMENTS = %w[AUTOMOBILE BUILDING FURNITURE MACHINERY HOUSEHOLD].freeze

    CONTAINER_TYPES = %w[
      SM CASE SM BOX SM PKG SM PACK LG CASE LG BOX LG PKG LG PACK
      MED CASE MED BOX MED PKG MED PACK
    ].freeze

    SHIPMODES = %w[REG AIR AIR MAIL FOB IN PERSON PERSONAL PICKUP COLLECT COD TRUCK RAIL].freeze

    RETURNFLAGS = %w[R A N].freeze

    LINESTATUS = %w[F O].freeze

    SHIPINSTRUCT = %w[
      DELIVER IN PERSON
      COLLECT COD
      NONE
      TAKE BACK RETURN
    ].freeze

    ORDERPRIORITIES = %w[
      1-URGENT
      2-HIGH
      3-MEDIUM
      4-NOT SPECIFIED
      5-LOW
    ].freeze
  end
end