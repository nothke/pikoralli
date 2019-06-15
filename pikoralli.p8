pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- pikoralli
-- by nothke


----------------
-- parameters --
----------------

lowrezmode = false

-- starting position
startx = 72
starty = 92.5

-- steering multipliers
spinmult = 0.3 --0.03
offthrotspinmult = 0.6
handbrakespinmult = 1.2

-- acceleration
throttlemult = 15
maxthrottle = 3
maxspeed = 5 -- speed limit
--spin = 0.9

longfric = 0.15
latconstfric = 0.3 -- constant friction, added to lateral speed
latpropofric = 1.5 -- proportional friction, multiplied with lateral speed

-- surface drag multipliers
grassdrag = 1.2
waterdrag = 6
barricadedrag = 9
handbrakedrag = 0.6

-- particle system
maxskidmarkpoints = 50

----------------
--- varyings ---
----------------

x=64 y=64

prevgear = 0

steer = 0
turnrate = 0
turn = 0.7

velo = {}
velo.x = 0
velo.y = 0

carx = 40
cary = 40

throttle = 0

speed = 0

rvdot = 0

-- time control
starttime = 0
laptime = 0
lastlaptime = 0
splittime = 0
splitdisplayduration = 3
splitdisplay = 0
personalbest = 10000 -- ~infinite
curgate = -1

gearchange = false

frametime = 0

handbrake = false
burnout = false

carsurf = 0
onroad = false
onbridge = false
ongrass = false
onwater = false
onbarricade = false

pi = 3.14

squash = 0.7
carlnt = 20
carwdt = 10

showinfo = false

velocam = {}

rallying = false

onfinishline = false
killcount = 0

bestsplits = {}
splits = {}
bestsplitdiffs = {}
bestsplitdiff = 0
gatesnum = 6
ranonce = false
debug = false

-- arrays
skidmarks = {}
gravelparticles = {}
dustparticles = {}
bloodparticles = {}
waterparticles = {}

function _init()
 if lowrezmode then poke(0x5f2c,3) end
 cls()
 velocam.x = 0
 velocam.y = 0

 skidmarks.fl = { points = {} }
 skidmarks.fr = { points = {} }
 skidmarks.rl = { points = {} }
 skidmarks.rr = { points = {} }
end

dt = 1/60

-- update at 60fps:
function _update60()
 -- inputs
 if (btn(0)) then steer = -1
 elseif (btn(1)) then steer = 1
 else steer = 0 end

 if (btn(5)) then
  startrally()
 end

 handbrake = btn(4)

 _speed = speed
 if _speed > -0.1 and speed < 0.1 then
  _speed = 0.1 end

 rpmperspeed = speed * 30

 -- fake gear simulation
 gear = flr(rpmperspeed / 31)
 if (prevgear ~= gear) then 
  gearchange = true
  sfx(1, 3)
 prevgear = gear end


 rpm = rpmperspeed % 31 

 -- engine sound
 --if throttle ~= 0 then
  sfx(0, 0, rpm, 6)
 --else
  --sfx(8, 0, rpm, 2)
 --end

 -- turbo
 --sfx(2, 2, rpm, 2)

 absrvdot = abs(rvdot)

 -- surface sounds
 if ongrass or handbrake then
 sfx(3, 1, 0, 1) 
 elseif onbridge then
 sfx(5, 1, 0, 4)
 elseif absrvdot > 1 then
 sfx(4, 1, absrvdot * 1, 1)
 elseif burnout then
 sfx(4, 1, 2, 1)
 else
 sfx(-1, 1) end
end

function startrally()
 addskidmarkpoint(skidmarks.fl, carx, cary, 0)
 addskidmarkpoint(skidmarks.fr, carx, cary, 0)
 addskidmarkpoint(skidmarks.rl, carx, cary, 0)
 addskidmarkpoint(skidmarks.rr, carx, cary, 0)

 carx = startx
 cary = starty
 velo.x = 0
 velo.y = 0
 turn = 0.87

 addskidmarkpoint(skidmarks.fl, carx, cary, 0)
 addskidmarkpoint(skidmarks.fr, carx, cary, 0)
 addskidmarkpoint(skidmarks.rl, carx, cary, 0)
 addskidmarkpoint(skidmarks.rr, carx, cary, 0)

 -- time control
 curgate = 0
 laptime = 10000
 rallying = true
end

function _draw()
 frametime += 1

 cls(6)

 -- camera
 cammid = 64
 if lowrezmode then cammid = 32 end
 camoff = 10 * 2.023 -- this changed
 if lowrezmode then camoff = 10 end

 velocam.x = lerp(velocam.x, velo.x, 0.2)
 velocam.y = lerp(velocam.y, velo.y, 0.2)

 camx = carx - cammid + velocam.x * camoff
 camy = cary - cammid + velocam.y * camoff
 camera(camx,camy)

 -- map, background:
 map(0,0,0,0,128,128,0)

 -------------
 -- physics --
 -------------
 
 speed = length(velo) * 2

 -- detect surfaces
 
 carsurf = mget( carx / 8, cary / 8)
 
 onroad = fget(carsurf, 2)
 ongrass = fget(carsurf, 3)
 onbridge = fget(carsurf, 6)
 onwater = fget(carsurf, 4)
 onbarricade = fget(carsurf, 0)

 -- when outside of the map, make sure it feels like water
 if carx < 0 or carx > 1024 then onwater = true end
 if cary < 0 or cary > 512 then onwater = true end

 tile = {
  x = flr(carx / 8),
  y = flr(cary / 8)
 }

 -- roadkill
 if fget (carsurf, 7) then
  mset( tile.x, tile.y, 61 ) 

  sfx(6)

  bpos = {x = carx, y = cary}
  bvelo = {x = velo.x, y = velo.y - 1}

  addparticle(bloodparticles, 100, bpos, 
   bvelo, 1, 30, 60)

  grvx = 42 + flr(killcount % 5)
  grvy = 1 + flr(killcount / 5)
  grv = 80+flr(rnd(3))
  mset(grvx, grvy, grv)

  killcount+=1
 end
 
 -- turning
 turnrate = steer * spinmult
 if throttle == 0 then turnrate = steer * offthrotspinmult end
 if handbrake then turnrate = steer * handbrakespinmult end

 -- limit turnrate when nearly stationary
 turnlimit = speed * turnrate * 1
 if (abs(turnlimit) < abs(turnrate)) turnrate = turnlimit

 turn = turn + turnrate * dt

 -- vectors
 forward = {}
 forward.x = sin(turn + 0.125)
 forward.y = cos(turn + 0.125)

 right = {}
 right.x = sin(turn + 0.375)
 right.y = cos(turn + 0.375)

 if btn(2) then throttle = maxthrottle / 2
 elseif btn(3) then throttle = -maxthrottle / 2 else
 throttle = 0 end

 if speed > maxspeed then throttle = 0 end

 velo.x = velo.x + forward.x * throttle * dt;
 velo.y = velo.y + forward.y * throttle * dt;

 rvdot = dot(velo, right)

 -- drag
 rvdotsgn = sgn(rvdot)
 latfric = latconstfric * rvdotsgn + latpropofric * rvdot
 velo.x -= right.x * latfric * dt
 velo.y -= right.y * latfric * dt

 surfdrag = 0
 if onbarricade then surfdrag = barricadedrag
 elseif ongrass then surfdrag = grassdrag
 elseif onwater then surfdrag = waterdrag end

 if handbrake then surfdrag += handbrakedrag end

 --pset(tile.x, tile.y, 10)

 velo.x -= velo.x * longfric * dt
 velo.y -= velo.y * longfric * dt

 velo.x -= velo.x * surfdrag * dt
 velo.y -= velo.y * surfdrag * dt

 -- apply velocity to position
 carx += velo.x
 cary += velo.y

 -- collide
 caractor = { 
  x = carx, 
  y = cary,
  w = 2,
  h = 2 }

 if solid_a(caractor, velo.x, 0) then
  --print('collide!', carx, cary)
  carx = carx - velo.x
  velo.x = -velo.x * 0.1 -- magic
  velo.y = velo.y * 0.5 -- magic

  if speed > 1 then sfx(9) end
 end

 if solid_a(caractor, 0, velo.y) then
  cary = cary - velo.y
  velo.y = -velo.y * 0.1 -- magic
  velo.x = velo.x * 0.5 -- magic
 end

 tx = carx / 8
 ty = cary / 8
 surf = {}
 add(surf, mget(tx, ty))
 add(surf, mget(tx + 1, ty))
 add(surf, mget(tx, tx + 1))
 add(surf, mget(tx + 1, tx + 1))


 -- skidmarks
 wbase = 5
 wwidth = 3
 wforward = { x = forward.x * wbase, y = forward.y * wbase}
 wright = { x = right.x * wwidth, y = right.y * wwidth }

 -- wheel positions
 flw = {
  x = carx + wforward.x - wright.x,
  y = cary + wforward.y - wright.y }

 frw = {
  x = carx + wforward.x + wright.x,
  y = cary + wforward.y + wright.y }

 rlw = {
  x = carx - wforward.x - wright.x,
  y = cary - wforward.y - wright.y }

 rrw = {
  x = carx - wforward.x + wright.x,
  y = cary - wforward.y + wright.y }

 skidintensity = absrvdot * 0.4 * 2
 if not onroad then skidintensity = 0 end

 if frametime % 4 == 0 then
  addskidmarkpoint(skidmarks.fl, flw.x, flw.y, skidintensity)
  addskidmarkpoint(skidmarks.fr, frw.x, frw.y, skidintensity)
  addskidmarkpoint(skidmarks.rl, rlw.x, rlw.y, skidintensity)
  addskidmarkpoint(skidmarks.rr, rrw.x, rrw.y, skidintensity)
 end

 drawskidmark(skidmarks.fl)
 drawskidmark(skidmarks.fr)
 drawskidmark(skidmarks.rl)
 drawskidmark(skidmarks.rr)

 if onwater and speed > 0.2 then
  emitvelo = { 
   x = velo.x *0.3, 
   y = velo.y *0.3 }

  addparticle(waterparticles, 1, flw, emitvelo, 1, 10, 20)
  addparticle(waterparticles, 1,  frw, emitvelo, 1, 10, 20)
  addparticle(waterparticles, 1, rlw, emitvelo, 1, 10, 20)
  addparticle(waterparticles, 1, rrw, emitvelo, 1, 10, 20)
 end

 odd = frametime % 2 == 0

 -- on throttle particles
 burnout = onroad and speed > 0 and speed < 3 and throttle > 0

 if burnout then
  emitvelo = { 
   x = velo.x - forward.x, 
   y = velo.y - forward.y }

  addparticle(gravelparticles, 1, rlw, emitvelo, 0.02, 8, 15)
  addparticle(gravelparticles, 1, rrw, emitvelo, 0.02, 5, 10)
 end

 -- sideways particles
 if onroad and skidintensity > 0.5 then
  emitvelo = {
   x = velo.x * 0.4 + right.x * rvdotsgn,
   y = velo.y * 0.4 + right.y * rvdotsgn,
  }



  if rvdotsgn < 0 then
   if (odd) addparticle(gravelparticles, 1, flw, emitvelo, 0, 10, 20)
   if (not odd) addparticle(gravelparticles, 1, rlw, emitvelo, 0, 10, 20)
  elseif rvdotsgn > 0 then
   if (odd) addparticle(gravelparticles, 1, frw, emitvelo, 0, 10, 20)
   if (not odd) addparticle(gravelparticles, 1, rrw, emitvelo, 0, 10, 20)
  end
 end

 exhaust = { 
  x = carx - forward.x * 6,
  y = cary - forward.y * 6}

 -- dust particles
 if onroad and speed > 2 and frametime % 2 == 0 then
  addparticle(dustparticles, 1, exhaust, {x = velo.x * 0.6, y = velo.y * 0.6}, 0, 20, 40)
 end

 -- update particle systems
 updateparticlesystem(gravelparticles)
 updateparticlesystem(dustparticles)
 updateparticlesystem(waterparticles)
 updateparticlesystem(bloodparticles)
 
 ---------------------
 -- rendering order --
 ---------------------

 --drawparticlesystemsprite(dustparticles, 112, 120)
 drawcarsprite()
 drawparticlescolor(bloodparticles, 8)
 drawparticlesystem(gravelparticles)
 drawparticlescolor(waterparticles, 7)

 -- exhaust boom sprite
 if (gearchange) then 
  sspr(16, 0, 8, 8, exhaust.x - 4, exhaust.y - 4, 8, 8)
  gearchange = false
 end

 -- debug lines
 if debug then
  dm = 10
  --line(carx, cary, carx + forward.x * 7,cary + forward.y * 7,12)
  line(carx, cary, carx + right.x * rvdot * dm, cary + right.y * rvdot * dm, 8)
  line(carx, cary, carx - right.x * latfric * dm, cary - right.y * latfric * dm, 10)
  line(carx, cary, carx + velo.x * dm, cary + velo.y * dm, 7)
  line(carx, cary, carx + -velo.x * surfdrag * dm, cary - velo.y * surfdrag * dm, 9)

  dx = camx + 2
  dy = camy + 64
  printshd(rvdot, dx, dy, 8) dy += 6
  printshd(latfric, dx, dy, 10) dy += 6
  printshd(speed, dx, dy, 7) dy += 6
  printshd(surfdrag, dx, dy, 9) dy += 6
  printshd(stat(1), dx, dy, 9) dy += 6
 end

 -- detect gates
 tilex = flr(carx / 8)
 tiley = flr(cary / 8)

 onfinishline = tiley == 11 and tilex >= 6 and tilex <= 11

 if curgate == 0 then
  if tiley == 57 then
   if tilex >= 6 and tilex <= 10 then
    nextgate() end end end

 if curgate == 1 then
  if tiley == 40 then
   if tilex >= 104 and tilex <= 109 then
    nextgate() end end end

 if curgate == 2 then
  if tiley == 36 then
   if tilex >= 42 and tilex <= 47 then
    nextgate() end end end

 if curgate == 3 then
  if tiley == 26 then
   if tilex >= 97 and tilex <= 103 then
    nextgate() end end end

 if curgate == 4 then
  if tiley == 18 then
   if tilex >= 120 and tilex <= 125 then
    nextgate() end end end

 -- time control

 -- start line
 t = time() / 2
 if onfinishline then 
  starttime = t

  -- finish  
  if rallying and laptime > 1 and curgate == 5 then
   lastlaptime = laptime

   setsplit(gatesnum) -- shows the last split time

   -- record
   if lastlaptime <= personalbest then
    personalbest = laptime

    -- set best splits
    for i=0,gatesnum do
     bestsplits[i] = splits[i]
    end
   end

   ranonce = true
   rallying = false
   curgate = -1
  end

 end

 laptime = t - starttime 
 --print(laptime, carx+ 5, cary + 5, 0)

 --------
 -- ui --
 --------

  -- laptime ui
 txtx = camx + 1
 txty = camy + 5

 if ranonce then
  local str = 'best '
  if (lowrezmode) str = 'b '
  printshd(str.. personalbest, txtx, txty, 12) txty += 6
  if (not lowrezmode) printshd('last '.. lastlaptime, txtx, txty, 14)  txty += 6
 end

 if rallying then
  local str = 'time '
  if (lowrezmode) str = 't '
  t = laptime
  if (lowrezmode) t = flr(laptime * 10) / 10
  printshd(str.. t, txtx, txty, 7) txty += 6
 end

 -- split
 if splitdisplay > 0 then
  spltx = camx + 128 - 55
  splty = camy + 128 - 20
  if lowrezmode then
   spltx = camx + 64 - 55
   splty = camy + 64 - 7
  end

  plus = ''
  splitdiffcol = 11
  if bestsplitdiff > 0 then
   splitdiffcol = 8
   plus = '+'
  end

  if ranonce then
  printshd('     '..plus.. bestsplitdiff, spltx, splty, splitdiffcol) end
  printshd('split '.. splittime, spltx, splty + 7, 7)
  splitdisplay -= dt
 end

 -- splits gates ui
 segwdt = 21
 if (lowrezmode) segwdt = 11
 segnum = 6
 gatey = camy + 1 --22
 gatex = camx + 1
 rectfill(gatex - 2,gatey - 2,gatex + segwdt * segnum + 1,gatey + 2,0)
 rectx1 = gatex + segwdt * segnum
 if (lowrezmode) rectx1 -= 4
 rect(gatex - 1,gatey - 1,rectx1,gatey + 1,7)

 for i=1,segnum - 1,1 do
  pset(gatex + i * segwdt - 1,gatey,7)
 end

 if curgate > -1 then
  for i=0,curgate,1 do
   last = 0
   if i == 5 then
    last = 1-- hack to strech the last one
    if (lowrezmode) last = -3
   end

   col = 11
   if i == curgate then col = 12
   elseif ranonce and bestsplitdiffs[i] > 0 then 
    col = 8 
   end
  
   line(gatex + i * segwdt,gatey,gatex + ((i+1) * segwdt) -2 + last,gatey,col)
  end
 end
 --print('gate '.. curgate, camx + 1, camy + 19, 7)

 -- input ui

 inputx = camx + 2
 inputy = camy + 128 - 7
 imult = 10
 inthr = throttle * 2 / maxthrottle  -- *2 is temporary 60fps
 if inthr < 0 then inthr = 0 end
 inbrk = -(throttle * 2 / maxthrottle)
 if inbrk < 0 then inbrk = 0 end
 inhbr = 0
 if handbrake then inhbr = 1 end
 y = inputy
 rectfill(inputx - 1,inputy - 1,inputx + imult + 1,inputy + 5,0)
 line(inputx ,y, inputx + ((speed * imult) / maxspeed), inputy, 7)  y += 1
 line(inputx ,y, inputx + inthr * imult, y, 11)  y += 1
 line(inputx ,y, inputx + inbrk * imult, y, 8)  y += 1
 line(inputx ,y, inputx + inhbr * imult, y, 12)  y += 1
 line(inputx + imult / 2 ,y, inputx + imult / 2 + imult / 2 * steer,y, 14)


 -- info screen
 showinfo = carsurf == 55

 txtx = camx + 32
 txtw = 64
 txty = camy + 32
 txth = 53

 if not lowrezmode and showinfo then
  rect(txtx-2,txty - 2,txtx + txtw + 1,txty + txth + 1,7)
  rectfill(txtx-1,txty - 1,txtx + txtw,txty + txth,0)
  print('     kiis:', txtx, txty, 12)
  txty += 6
  print('erous tu draiv', txtx, txty, 12)
  txty += 6
  print('x tu start ralli', txtx, txty, 12)
  txty += 6
  print('z tu hendbreik', txtx, txty, 12)
  txty += 6
  txty += 6
  print('ju stiir beter', txtx, txty, 12)
  txty += 6
  print('of trotel end', txtx, txty, 12)
  txty += 6
  print('hbrejk iven moor', txtx, txty, 12)
  txty += 6
  print('   bii faast.', txtx, txty, 12)
 end
end -- end of draw

-- copied from collide.p8 demo
function solid(x, y)
 --pset(x, y, 10) --debug
 val=mget(x/8, y/8)
 return fget(val, 1)
end

function solid_area(x,y,w,h)
 return 
  solid(x-w,y-h) or
  solid(x+w,y-h) or
  solid(x-w,y+h) or
  solid(x+w,y+h)
end

-- checks both walls and actors
function solid_a(a, dx, dy)

 if solid_area(
   a.x+dx,a.y+dy,
   a.w,a.h) then
  return true
 end
end

function nextgate()
 setsplit(curgate)

 curgate += 1
end

function setsplit(_gate)
 splittime = laptime
 splits[_gate] = splittime

 if bestsplits[_gate] ~= nil then
  bestsplitdiff = splittime - bestsplits[_gate]
  bestsplitdiffs[_gate] = bestsplitdiff
 end

 splitdisplay = splitdisplayduration
end


function drawcarsprite()

 w = 1

 -- bottom
 imgx = 32
 imgy = 32
 rspr(0,0, imgx,imgy,turn + pi,2)

 -- top
 topx = 48
 topy = 32
 rspr(0,16, topx, topy, turn + pi, 2)
 
 -- render
 sspr(imgx,imgy,16,16,carx-8*w,cary-8*w,16*w,16*w)
 
 sspr(topx, topy, 16, 16, carx-8*w, cary - 1 -8*w, 16*w, 16*w)
 sspr(topx, topy, 16, 16, carx-8*w, cary - 2 -8*w, 16*w, 16*w)
end

-- skidmarks --

function addskidmarkpoint(skidmark, x, y, intensity)
 
 point = {}
 point.x = x
 point.y = y
 point.intensity = intensity

 add(skidmark.points, point)

 if #skidmark.points > maxskidmarkpoints then 
  v = skidmark.points[1]
  del(skidmark.points, v)
 end
end

function drawskidmark(skidmark)
 for i=1,#skidmark.points - 1,1 do
  if skidmark.points[i].intensity > 0.5 then
   line(skidmark.points[i].x, skidmark.points[i].y, skidmark.points[i+1].x, skidmark.points[i+1].y, 4)
  end
 end
end

---------------
-- particles --
---------------

function addparticle(_ps, _count, _pos, _velo, randomdir, minlife, maxlife)

 for i=0,_count do
  randmult = 0.5 + rnd(100) / 100
 
  if randomdir ~= 0 then
  -- random vector
   randx = (-1 + rnd(2)) * randomdir
   randy = (-1 + rnd(2)) * randomdir
  
   velox = (_velo.x + randx) * randmult
   veloy = (_velo.y + randy) * randmult
  else
   velox = _velo.x * randmult
   veloy = _velo.y * randmult
  end
 
  randlife = flr(rnd(maxlife - minlife))
  flp = false
  if randlife % 2 == 0 then flp = true end
 
  particle = { 
   pos = {x = _pos.x, y = _pos.y }, 
   velocity = {x = velox, y = veloy},
   startlife = minlife + randlife,
   lifetime = minlife + randlife,
   flp = flp} 
 
  add(_ps, particle)
 end
end

function updateparticlesystem(ps)
 for i=#ps,1,-1 do
  particle = ps[i]

  if particle.lifetime < 1 then -- kill
   v = ps[i]
   del(ps, v)
  else
    vmult = 1 - (1.5 * dt)  -- magic

    particle.velocity.x *= vmult
    particle.velocity.y *= vmult

    particle.pos.x += particle.velocity.x
    particle.pos.y += particle.velocity.y

    particle.lifetime-=1 * 0.5 -- temp convert to seconds or smth


  end
 end
end

function drawparticlesystem(_ps)
 --if ps ~= nil then

  for i=#_ps,1,-1 do
   particle = _ps[i]
 
   if particle.lifetime > 10 then
    --line(lastx, lasty, particle.pos.x, particle.pos.y, 9) else --vpset(particle.pos, 0)
    vpset(particle.pos, 0)
    --pset(particle.pos.x, particle.pos.y + 1, 9)
    else
    vpset(particle.pos, 4)
   end
  end
 --end
end

function drawparticlescolor(_ps, _col)
  for i=#_ps,1,-1 do
   particle = _ps[i]
   vpset(particle.pos, _col)
  end
end

function drawparticlesystemsprite(ps, spritestart, spriteend)
 diff = spriteend - spritestart
 
 for i=1,#ps,1 do
 --for i=#ps,1,-1 do
  particle = ps[i]

  lifemult = particle.lifetime / particle.startlife

  spritenum = flr(spriteend - lifemult * diff)

  y = 56
  x = flr(diff - lifemult * diff) * 8
  sspr(x,y,8,8,particle.pos.x - 8,particle.pos.y - 8,16,16, particle.flp)
 end
end

----------------
-- draw utils --
----------------

-- set pixel color at vector
function vpset(v, col)
 pset(v.x, v.y, col)
end

-- set pixel color at vector and write text
function vpsetp(v, col, text)
 pset(v.x, v.y, col)
 print(text,v.x,v.y + 2,col)
end

function rectangle(v1, v2, v3, v4)
 triangle(v1, v2, v3)
 triangle(v2, v3, v4)
end

-- sprite rotation, from lexaloffle.com/bbs/?tid=3593
function rspr(sx,sy,x,y,a,w)
 local ca,sa=cos(a),sin(a)
 local srcx,srcy,addr,pixel_pair
 local ddx0,ddy0=ca,sa
 local mask=shl(0xfff8,(w-1))
 w*=4
 ca*=w-0.5
 sa*=w-0.5
 local dx0,dy0=sa-ca+w,-ca-sa+w
 w=2*w-1
 for ix=0,w do
  srcx,srcy=dx0,dy0
  for iy=0,w do
   if band(bor(srcx,srcy),mask)==0 then
    local c=sget(sx+srcx,sy+srcy)
    sset(x+ix,y+iy,c)
   else
    sset(x+ix,y+iy,rspr_clear_col)
   end
   srcx-=ddy0
   srcy+=ddx0
  end
  dx0+=ddx0
  dy0+=ddy0
 end
end

----------
-- math --
----------

function clamp(min, max, value)
 if (value < min) value = min
 if (value > max) value = max

 return value
end

function normalize(v)
 l = length(v)
 v.x = v.x/l
 v.y = v.y/l
 return v
end

function dot(v1, v2)
 return v1.x * v2.x + v1.y * v2.y
end

function length(v)
 return sqrt(v.x*v.x + v.y*v.y)
end

function lerp(tar,pos,perc)
 return (1-perc)*tar + perc*pos;
end

-- print with shadow
function printshd(text, x, y, col)
 print(text, x+1, y+1, 0)
 print(text, x, y, col)
end

----------
-- menu --
----------

function togglelowrez()
 lowrezmode = not lowrezmode
 if lowrezmode then poke(0x5f2c,3)
  else poke(0x5f2c,0) end
end

menuitem(2, "start rally", startrally)
menuitem(3, "lowrez mode", togglelowrez)
menuitem(4, "toggle debug", function() debug = not debug end)
__gfx__
000000000000000000000000ffffffff3455ffff33333333333333333ddd333353335333dd33333399333333333333333333333333333333ffffffff86666668
000000000000000000a77a00ffffffff4545ffff35553333333333333533335339333935333ddddd33999333333333333376673333766733ffffffff68867887
000006666660000009a99990ffffffff545fffff335355533333333333533dd333533333333333553333333333333333336aa63333688633ffffffff66888866
0000557667550000099779a0ffffffff55ffffff333535353333333333335333333333533ddd33339935555533533333336aa633336886336565656577887666
000055766755000009a779a0ffffffffffffffff5335333333333333333333dd3353933333333333333333333333333333766733337667335656565666888666
000007777770000000999990ffffffffffffffff35553333333333333333533335333335ddd33dd335533399333335333377773333777733ffffffff88778876
00000ce77ec0000000999000ffffffffffffffff33335533333333333dddd333333333535533333333333333333333333373373333733733ffffffff86666686
00000ce77ec0000000000000ffffffffffffffff3333335333333333333333353333533333dddd3333399993333333333333333333333333ffffffff86667788
00000ce77ec000000000000049ffffffffff54535353535333333333fffff553545f5ffffffffffffffff4fffffffffffffffffffffa5ffffffff55366666666
000007e77e70000000000000545ffffffffff5454545454555333333ffff5ff535ff5ffffff555fffffff4fffffffffffffffffffff55fffffff5ff599999999
000007e77e7000000000000035495fffffff5f545454545499553333ffffff53545fffffffffffffff4f44fffffffffffffffffffff5afffffffff5366966966
000055e77e55000000000000b3549ffffffff5f5f5f5f5f554595333fffff5455445ffffffffffffff4f44ffffffffffa55aa55afffaafff65656545ffffffff
000055e77e55000000000000333545fffffffffffffffffff5545333ffffff5335545ffff55ffffff44ff4ff5f5fffff55aa55aafffa5fff5f5f5f5344444444
000007e77e700000000000003b335495fffffffffffffffff5459533ffff5ff55455ffffffffffffff4f44ff45f5ffff6ffffff5fff55fffffff5ff544444444
000000000000000000000000b33b3549ffffffffffffffffff545453ffffff5335ff5fffffff555fff4f44ff545fffff6ffffff5fff5afffffffff5355555555
000000000000000000000000333b3554fffffffffffffffffff54595fffff545545ffffffffffffffffff4ff3545ffff6ffffff5fffaaffffffff54544444444
000000000000000000000000ffffffff5495ffffffffffffff5f544533333355ffffffff44ffffff33333333335153333334433333553333545f5fff44444444
000000000000000000000000ffffffff354ffffffffffffff5f544533333545ff4fff4ffffffffff33333300511515333334f333335f377335ff5fff44444444
000000000000000000000000ffffffff335495ffffffffffff544533333355f5ff4fff4ffff444443333335115151133333bb333338837f3545fffff55555555
000000555500000000000000ffffffff3395495ffffffffff545533333354f5f4ff4ffffffffffff333315151511515333b77333389939935445656544444444
000000eeee00000000000000fffff5f5b33394f5f5f5f5f55545333333545f5fffff4fffffffffff3331151511515113331bb333318835933554565644444444
000006e77e60000000000000ffff5f543333354954545454f55333333545f5ffff4ff4ff44444fff331005115151151533316333331635935455ffff55555555
000005ecce50000000000000fffff545bb3333544545454559333333445f5ffffff4ff4fffffffff3104805151151573333165533316516335ff5fff44444444
000005ecce50000000000000ffff5453333b3335353535355333333355f5ffffffff4ffff44fffff10848451151578733333333333333165545fffff44444444
000005ecce500000000000003333333333355333333a533333663333ff515fffffff4ffffffff4ff078484051570787333334433333333333333333344444444
000006e77e60000000000000333333333336aa3333355333336f3333ff1c1ffffff4fffffff54fff378484704877487337734f33333388333333333355555555
00000566665000000000000033333333333635533335a33333573333f5115fffff4ffff4ff54ffff378484714848487337f3dd333388f8833333333344444444
00000055550000000000000053333333333333aa333aa33333153333f1cc1fffffffff4ff5ffffff378484784848455336635d33388f8883a55aa55a44444444
0000000000000000000000005a3333333333333a333a533333153333f51c1fffffff44ff5fffff4f3784847848455533cc635d333888888355aa55aa44444444
0000000000000000000000006a533333333333353335533333153333f51c15ff4444fff4fffff4ff35548478455353531cc3163338ff83336333333599999999
000000000000000000000000635a3333333333353335a33333115553f1ccc1fffffff44fffff4fff335554755535353331631655333883336333333544944944
000000000000000000000000333aa33333333333333aa33333333333f51115ffff444ffffff4ffff3535355353533333316553333333333333333333ff9ff9ff
000000000000000000000000000000007000000000000007800000000000000833399333333aa333333333333333b33366666666333333343933393343333333
0000000000000000000000000000000000000000000000000000000000000000399499333a94aa3339b4b933333b5133666666663333393944449444f9333333
000000000000000000000000000000000077700000000000088888000000000094943954a4a43a543494395433b5151366666666333333464797964669493333
00000000000000000000000000000000007070000000000000080000000000003494994334a4a9433494b9433b51b15166666666333994966666666666f43333
000000000000000000000000000000000077770000000000000800000000000093343499a33434a99b3434b9351b531166666666333949776666677766994333
0000000000000000000000000000000000700700000000000008000000000000493543434a3543434b3543b3bbb51551666666663949666666677777666f9433
0000000000000000000000000000000000777700000000000000000000000000343794933437a4a33430b4931155b13366666666946667776666666666696f43
000000000000000000000000000000000000000000000000000000000000000033474393334743a333b043b33bbb5311666666664666666666666666666666f3
333333333333333333333333000000000000000000000000000000000000000094309394a437a39494379b943515b55539a4339a396777776666666666666743
3336333333565633676333330000000000000000000000000000000000000000394039433a403a4333b73943315b41113394a339346666666666777767776993
33666333336565333676333300000000000000000000000000000000000000005357349353373493533034933bb155339a3433a3346677666666666666669443
336663333356563337673333000000000000000000000000000000000000000033374399533743aa5337b39b3515b1553947a933946666777777766677669933
336563333365653333767333000000000000000000000000000000000000000033303333333733333330333331bb45114a379334396666666666666666666433
33666553335656553367655300000000000000000000000000000000000000003337535333305353333053533b534353943439a3946777776777777677779493
3344433333444433334443330000000000000000000000000000000000000000333055353330553533305535353545359a979493396666666666666666666433
33333333333333333333333300000000700000000000000780000000000000083333535333335353333353533353535399304333349777776666777766776943
00000000000000000000000000000000000000000000000000000000000000000000000000000000ffb4bfaf3333b33333333333346966666666666676666943
00000000000000000000000000000000000000000000000000000000000000000000000000000000faa4abf43333b13333333333339677776667777777779433
00000000000000000000000000000000000000000000000000000000000000000000000000000000f4a49a4b33bb151333333333333469666666666666664933
0000000000000000000000000000000000000000070000700f7007f00ff00f400000000000000000bf94a4fabb11b15333333333333947776777976679943333
000ff000000440000004400000044000700ff007f00ff00f4000000440077004000000000000000049b49bb5115b431535333333333334666969777966433333
00077000000ff0000041140070411407ff0440ff44044044410ff0041440444400000000000000009497495433b115515353533333333949f4f94f9494933333
000000000070070007f00f700f1001f04410044f144044411ff004400111111000000000000000004a909b453b15113335353533333333944444444443333333
0000000000000000000000000000000000000000011011100100000000000000000000000000000039a0b5b53151431353535333333333393333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
00ff000000f0f00000fff00000f9f90f00f90900000f0f000000000000f000000ff00000000000000000000000000000333333333333333333cacc33337c7733
0fff400000f44f000ff44f000ff44ff00fff0ff00f900f90090000f00f000ff0944f0ff000000000000000000000000033333333333333333caaaaa337ccccc3
014ff400ff4ff0005f4ff4f05f4ff4f954f004f9540000f9500000f9190000f44000f049000000000000000000000000a57c755a3313333333ccacc33377c773
00551f40044ff9f04445f9444455f944f45ff94ff450094f4f0009044f0009011f00004f000000000000000000000000557c75aa3117788333c3333333733333
001151100041500f014454f4144f54f4144f5ff4144f0ff41400f4f41400f411140009f100000000000000000000000063ccc335331177883333333333333333
000000000011100000115110015154100f5154400451544001f0041001f0041001000f10000000000000000000000000637c7335333177883333333333333353
000000000000000000000000001510000115100001151000001f1000001010000100010000000000000000000000000033337333333333333333333333335333
c4e5f5b6b4c5709480607240525252525252b130304161606060a0806060d4e4e4f4b0d4e4f46060a480508130303262508060425252a652525252a6a6525252
5262506085c6a06060d4e5c4c4e5e5e6e6f6a4a5c695c65080607251515151515151403030307160b5c6707080708060b5c660b4b4b460b5c660b5b5c66060d5
e5c4f5b5b5957085c672406260607070606042b1303041616080806060d4e5e5c4e5e4e5e5e5f460c594808130307160a060946060a495c68480608485c68070
94a4805060606060d4e5c4c4e5e5f684606085c660b4608070723030303030303030303030304161707090b470a0b4808060b4b5c6b5c6b46060b5b5c660d5e5
c4c4f560b4508470724062e3e3e3e3e3e3e38042b13030416160a08060d5e5e5c4c4e5e5c4c4f56085c5608130307150806084a494a5948485a494a4a5a494a4
a585c650806060d4e5c4e5e6e6f66095c6606090b6b5c670723030303032525252525252b1303041617070b5c6a0b5b4b4b4b4b56060b5b5c6b4b5b5c660d5e5
c4e5f6b6b59485c68171d270606060706060606081303030716080b0d4e5e5c4e5e5e6e5e5c4f56060c56081a13071c280a0a5a595b09595b0a595a5a485a585
a5c660806060d4e5c4e5f6a46060a2b2b0906060b5c65060813030303062606080806060423030304161909090b470b5b6b6b5b4b6b5b66060b5b6c66060d5e5
c4f5b4b5c685c6a481716070a4609070706060608130303071b06060d5e5c4e5e5f6b0d6e5c4f5806085c081303071c060609460958494a4b09484b095c6a460
606060606060d5c4c4f560a5a2b2a3b3b0b09090606080608130303071608080a0808060604230303041617090b47070b5b5c6b6b5b4b660b4b5b6907090d5e5
e5f5b5c6a08050858171846085c660607060606081303030716080a0d6e5c4e5f5a2b294d5c4f58060606081a13071608084a5c6b0a585a594a585846060a594
606080606060d5c4e5f56060a3b372616060606060808072303030307160a0a08460a080946042303030416190b5c69060b4b46060b6b460b4b5b4c6b460d5e5
e5f5607251515151407185c660c2609060706060813030307160608060d5e5e5f5a3b395d5e5f5a060606081a1307180a0a5c6b0a4a460b095c684a5c6606095
c67251515151f1f1f1f15161607292629060606050a06081303030307160a08095c6948085c660423030304161608090b4b6b5b5b4b6b5b4b4b6b5c6b570d5e5
e5f660425252a652a662949460e3e3e3e3e3336081303030718080a060d5e5c4e5f4b0d4e5e5f580a0606081a130716080a0a0949595c6a485c685c660606060
724030303030f2f2f2f230415192626060a05060a08060813030303071608080a060958480a0606042303030716080a0b5c6b4b4b5b5b4b5b6b4b6c67070d5e5
f5a2b260a460808085a4c585c66060d2c390536081303030716080a0d4e5c4e5c4e5e4e5e5c4e5f460806081a1307160a0909095c6706095c660606060725151
303032525252f3f3f3f352303071606080a06080a06072303030303262806080a0846085a080c260c081303071c0807080b4b4b4b5b4b4b6b4b6c6b6b460d5e5
f5a3b3608560a48080a4959460a470c270c353608130303071b06060d5c4e5e6e6e5e5c4c4c4e5e5f4a080818282715060806090907060606060606072403030
303262606080d5c4e5f5604230416150a080a0606072403030303062606080a09485c660a0848060608130303061606090b5b6b6b5b4b5b4b5b5b4c6b6c6d6e5
c4f460606094855084858485c685c660807053808130303071b060a0d6e6f68494d6e5e5c4c4e5e5f5d760813082416150606060606070606060607240303252
526260846094d5c4e5e5f460423041515151515151303030303071608060a08085c69480a095c6606081303030d161c2606060b5c6b5c6b5b4b4b5b6b6b4b4d5
c4f560a46085a49485948560a46080a0a0d2536042b191307160b080806084859560d6e5c4c4e5e5f6e760813030824151515151515151515151514030326260
8460609560a5d5c4c4e5f580604230303030303030303030303262606080a0a494609580a0a080607230303030d1415151515151516160b4b5b6b4b5b6b5b5d5
e5f560c5a46085c56084a09485c6a080c39053906042b1304161606060a08560608460d5e5c4e5f560d26042b130303030929291309130309130303032626080
a560a4d4e4e4e5e5c4e5f5806060425252525252525252525262606080a084858584a4a0a08060723030303032525252525252a6524161b5c6b6b6b4b4c670d5
c4f5948585a460959485c685c6b0b0c360d25370906042b13041616080a08080608560d6e6e5e5f560c350604252525252525252525252525252525262708070
808085d5e5e5e5c4c4e5e5f4a0846060606060806060806060609480808495c66095858060607230303030326260606060b460956042416160b5c6b6b67070d5
e5f585c66085c68085c660b060e3e3e3e3e343e3e3e360313091416160606060a0a0606094d6e5e5f4606060606080606080806060606060606060608070d4e4
e4e4e4e5e5e5c4c4c4e5e5e5f4959460808080a0a0809480608084a09485c6a49460a06060723030303032626080706060b56060b4604241515161b5b5b460d5
c4f6608080a4608080a06060b0b060c26070705070609060319130416160609460808060c560d5c4e5f460a0808080a08060508050d4e4e4e4e4e4e4e4e4e5e5
e5e5e5e5e5c4c4c4c4c4c4e5e5f485946080a0a0a49495c6a0a085c695c684a5958480606081303030326260807070b0b0b4b5b4b5b0b4423030306160b5c6d5
f560b08060a5c680a0a06060707060606060606060607060708130834161608560a060608560d6e5e5e5f460c2c3a06060d4e4e4e4e5e5e5e5e5c4c4c4c4c4c4
c4e5c4e5c4c4c4c4c4c4e5c4e5e5f485c68460609585c6a084606060609495c66095c6606081303030626080807070b0b0b5b4b5b4b4b56042303041616060d5
f59460b0c3a2b260808060709060607251515151516160707230309130a1616060608060606060d6e5c4e5f460606060d4e5e5e5e5e5c4c4c4c4e5e5c4c4e5e5
c4c4c4e5c4c4c4c4c4c4e5e5c4e5f580a085c6a08080946085c694606085c66080a08060608130307160807070e3e3e3e3e3b5b4b0b5b0b460813030416160d5
f595c66060a3b3806060707060607230303030303041617230303032b1a1a1616080a46060606060d6e5c4e5e4e4e4e4e5e5e5c4c4c4c4e5e5e5e6e6e6e6e6e5
e5e5e5c4c4c4c4c4c4e5e5c4e5e5f584c3d2a094d2c395d26094a5c6c2a0a08060606060724030307160807060b060b0b06060b5606060b560813262424161d5
f560607251516160607090706072303030525252b18230303083326231c1c1c1616085a06060608460d6e5c4c4c4e5c4c4c4c4c4e5e5e5e5e5f680a0a08080d6
e6e5c4e5e5c4c4c4e5c4e5e5e6e6f685c6e3e395e3e380806085a0a0a080606060607251403030326280907060b0b0b0b0b0b0b0b090906060817160608171d5
f5a2b2425252b161609090607230303071a080a042b13092833262806042a1a1916160a094a06085a460d6e6e6e6e6e6e6e6e6e6e6e6e6e6f6b06080806060b0
b0d6e5e5c4e5e5e5e5e5e5f680806060725151515161608080a080606060606072514030303252626090706060b0b060b0b060609090907060817160608171d5
f5a3b380606042b16190907230309130716080606042525252626060606031a1a14161608560609485609460d260c3d260c280a06080a0606060725151515161
60b0d5e5e5c4e5e5e5e5f680a06072514030303030415161606060606060725140303032526260609090606060606060606060606090907060817160608171d5
f580a08080606042b15151303091303262606060807070806060e3e38060603191a1416160a084c5606085c2e3e3e3e3e3e36080b06060607251403030303030
6160d6e6e5e5e5c4e5f6b080607240303030919291303041515151515151403030325262606070709060606060d4e4e4e4e4e4e4f470907060817160608171d5
f56060a060606072403091928330326260707070709070e3e3e3e3e3e3e3606031c1c1c161a085856060606060e760d760606060606072514030325252523030
30616080d6e5c4e5f5b06060723030303092929192913091309130303030303252626060909090706060b0d4e4c4e5c4e5e5e5e6f670906072306260608171d5
f5608080a060608130325252525262607070709090706060606060606060a0a06031a1a14151515151515151515151515151515151514091303262b050603191
9130616080d5e5e5f56060723030303252525252525252525252525252525262607090707060706060d4e4c4e5c4e5e5e5e5f6707090606081716084608171d5
f560a0c3f760c081a171c050709072515151515151515151515151515151515151513091309130303030303030303030913030303091303032625060d4f45031
9130306160d6e6e6f660723030303262606060606060606060606060607070709090706060606060d4c4c4c4e5e5e5c4e5f5b0709060a2b2817160c5608171d5
e5f4c2d2a0606042b18251515151403030303030303030309292913030303030303030303032525252525252525252525252525252525252629060d4e5e5f460
31303041515151515151403030326260707090906060e3e3e3e3e3609560607060606060606060d4c4e5c4e5c4c4e5c4c4e5f4707060a3b3817160c5608171d5
c4e5f4608060606042b192923030303030325252525252525252525252525252525252525262606060606060b460b06060707070907060907060d4e5e5c4e5f4
603130303030303092913030326270709090707060d4e4e4e4e4e4f460a56060d4e4e4e4e4e4e4e5c4e5c4c4c4c4c4c4c4e5c4e4f4606060817160c5608171d5
c4e5e5f46094a0606042525252525252526260606060606060606070907090b6b49070b460b06060b080b460b5c660b0d4e4e4f47090906060d4e5e5c4e5e5f5
606042525252525252525252626090907060a460d4e5e5e5e5e5e5c4e4e4e4e4c4e5e5e5c4e5c4c4e5c4c4c4c4c4c4c4c4c4c4c4f560606081716095608171d5
c4c4e5e5f4a5a48080a08050505060606060707090607090709070609060b4b5b5b4b4b5b460d4e4e4f4b5c6d4e4f4d4e5c4c4e5e4e4e4e4e4e5e5c4c4c4e5f5
60606060b070607060706090909090606094a5d4e5c4c4c4c4e5c4c4c4c4c4c4c4c4c4e5e5e5e5e5c4c4c4c4c4c4c4c4c4c4c4c4c4f4d36042415151514062d5
c4e5c4c4e5f485c6808080a080607090907090707090d4e4e4e4e4f46060b5c690b5b5c6b5d4e5c4c4e5f4d4e5c4e5e5c4e5c4e5c4c4c4c4c4c4c4c4c4c4c4e5
f46080b06070709090909070606060606095d4e5c4c4c4c4c4c4c4e5c4c4c4e5e5c4c4c4c4e5c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4f460604252525262d4e5
c4c4c4c4c4c4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e5c4c4c4c4e5e4e4e4e4e4e4e4e4e4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4
c4e5e5e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e5c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4e4e4e4e4e4e4e4e5c4
__label__
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
70000000000000000000070000000000000000000070000000000000000000070000000000000000000070000000000000000000070000000000000000000007
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666666666666666666669443333333333333333333333333545fffffffffffffff4f44ffffffff5333333333333333553333333333333333333333333333
66666666666677777666776699333333333333333333333333335445ffffffffffffff4f44fffffff545333333333ddd33333333333333333333335333333353
666666666666666666666666643333333333333333333333333335545ffffffffffff44ff4ffffffff5333333333333333333333333333333333333333333333
66666666666667777776777794933333333333333333333333335455ffffffffffffff4f44ffffff5ff533333333ddd33dd33333333333333333333335333333
666666666666666666666666643333333333333333333333333335ff5fffffffffffff4f44ffffffff5333333333553333333333333333333333333333333333
6666666666666666777766776943333333333333333333333333545ffffffffffffffffff4fffffff5453333333333dddd333333333333333333333333333333
6666766669433469666676666943533353333333333333333333545f5ffffffff4fffffffffffffff5533333333333333333333333333ddd3333333333333ddd
777777779433339677777777943339333935333333333333333335ff5ffffffff4ffffffffffffff5ff533333333333333333333333335333353333333333533
6666666649333334696666664933335333333333333333333333545fffffff4f44ffffffffffffffff5333333333333333333333333333533dd3333333333353
76667994333333394777799433333333335333333333333333335445ffffff4f44fffffffffffffff54533333333335333333353333333335333333333333333
666666433333333334666643333333539333333333333333333335545ffff44ff4ffffffffffffffff53333333333333333333333333333333dd333333333333
77769493333333333949949333333533333533333333333333335455ffffff4f44ffffffffffffff5ff533333333333335333333353333335333333333333333
666643333333333333944333333333333353333333333333333335ff5fffff4f44ffffffffffffffff533333333333333333333333333dddd333333333333ddd
7777333333333333333933333333333353333333333333333333545ffffffffff4fffffffffffffff54533333333333333333333333333333335333333333333
6743333333333333b33353335333533353333333333333333333545f5fffffffffffffffffffffffffff3333333353335333333333333ddd3333333333333333
6993333333333333b1333933393539333935333333333333333335ff5fffffffffffffffffffffffffff55333333393339353333333335333353333333333333
94433333333333bb151333533333335333333333333333333333545fffffffffffffffffffffffffffff99553333335333333333333333533dd3333333333333
993333333333bb11b153333333533333335333333333333333335445ffffffffffffffffffffffffffff54595333333333533333333333335333335333333333
643333333333115b43153353933333539333333333333333333335545ffffffffffffffffffffffffffff55453333353933333333333333333dd333333333333
94933333333333b11551353333353533333533333333333333335455fffffffffffffffffffffffffffff5459533353333353333333333335333333335333333
6433333333333b1511333333335333333353333333333333333335ff5fffffffffffffffffffffffffffff54545333333353333333333dddd333333333333333
6943333333333151431333335333333353333333333333333333545ffffffffffffffffffffffffffffffff54595333353333333333333333335333333333333
6743333333333515b555333333333333b33333333333333333335495ffffffffffffffffffffffffffffffffffff33333333dd333333333333333ddd33335333
699333333333315b411133333333333b51333333333333333333354ffffffffffffffffffffffffffffffff555ff55333333333ddddd33333333353333533933
9443333333333bb155333333333333b515133333333333333333335495ffffffffffffffffffffffffffffffffff99553333333333553333333333533dd33353
9933333333333515b155333333333b51b15133333333333333333395495fffffffffffffffffffffffffffffffff545953333ddd333333533333333353333333
64333333333331bb451135333333351b53113333333333333333b33394f55f5ffffffffffffffffffffff55ffffff55453333333333333333333333333dd3353
9493333333333b53435353535333bbb5155133333333333333333333354945f5fffffffffffffffffffffffffffff5459533ddd33dd333333533333353333533
64333333333335354535353535331155b1333333333333333333bb333354545fffffffffffffffffffffffff555fff54545355333333333333333dddd3333333
69433333333333535353535353333bbb53113333333333333333333b33353545fffffffffffffffffffffffffffffff5459533dddd3333333333333333353333
674333333333333333333333b3333515b5553333333353335333333333335495fffffffffffffffffffffffffffffffff55333333333333333333ddd33333ddd
69933333333333333333333b5133315b4111333333333933393533333333354fffffffffffffffffffffffffffffffff5ff53333333333333333353333533533
9443333333333333333333b515133bb15533333333333353333333333333335495ffffffffffffffffffffffffffffffff53333333333333333333533dd33353
993333333333333333333b51b1513515b1553333333333333353333333333395495ffffffffffffffffffffffffffffff5453333333333533333333353333333
64333333333333333333351b531131bb4511333333333353933333333333b33394f55f5fffffffffffffffffffffffffff533333333333333333333333dd3333
94933333333333333333bbb515513b5343533333333335333335333333333333354945f5ffffffffffffffffffffffff5ff53333333333333533333353333333
643333333333333333331155b13335354535333333333333335333333333bb333354545fffffffffffffffffffffffffff5333333333333333333dddd3333ddd
694333333333333333333bbb531133535353333333333333533333333333333b55653545fffffffffffffffffffffffff5453333333333333333333333353333
666643333333333333333515b5553333b3339933333353335333333333333355eee6545f5ffffffffffffffffffffffff55333333333dd333333333333333ddd
7777f933333333333333315b41113333b133339993333933393533333333365e77e535ff5fffffffffffffffffffffff5ff533333333333ddddd333333333533
666669493333333333333bb1553333bb1513333333333353333333333333356eccee545fffffffffffffffffffffffffff533333333333333355333333333353
766666f43333333333333515b155bb11b1539935555533333353333333333565ecce5445fffffffffffffffffffffffff545333333333ddd3333335333333333
6666669943333333333331bb4511115b43153333333333539333333333333575ecce65545fffffffffffffffffffffffff533333333333333333333333333333
7776666f9433333333333b53435333b115513553339935333335333333333335ee776555ffffffffffffffffffffffff5ff533333333ddd33dd3333335333333
666666696f4333333333353545353b1511333333333333333353333333333335666655ff5fffffffffffffffffffffffff533333333355333333333333333ddd
7777666666f3333333333353535331514313333999933333533333333333333c5555575ffffffffffffffffffffffffff5453333333333dddd33333333333333
66666666666643333333333333333515b55533333333993333335333533333335555e55f5ffffffffffffffffffffffff553333333333333b333dd3333333333
666666667777f933333333333333315b411133333333339993333933393533337e77ee5f5fffffffffffffffffffffff5ff533333333333b5133333ddddd3333
66666666666669493333333333333bb15533333333333333333333533333333355e77e7fffffffffffffffffffffffffff533333333333b51513333333553333
66667777766666f43333333333333515b155333333339935555533333353333355e75445fffffffffffffffffffffffff545333333333b51b1513ddd33333333
666666666666669943333333333331bb45113333333333333333335393333333373335545fffffffffffffffffffffffff5333333333351b5311333333333333
666667777776666f9433333333333b534353333333333553339935333335333333335455ffffffffffffffffffffffff5ff533333333bbb51551ddd33dd33333
66666666666666696f4333333333353545353333333333333333333333533333333335ff5fffffffffffffffffffffffff53333333331155b133553333333333
666666667777666666f3333333333353535333333333333999933333533333333333545ffffffffffffffffffffffffff545333333333bbb531133dddd333333
6666666666666666666643333333333333333333b333333333335333533333333333545f5ffffffffffffffffffffffff553333333333515b5553333b3333333
66666666666666667777f933333333333333333b513333333333393339353333333335ff5fffffffffffffffffffffff5ff533333333315b4111333b51333333
66666666666666666666694933333333333333b51513333333333353333333333333545fffffffffffffffffffffffffff53333333333bb1553333b515133333
6666666666667777766666f43333333333333b51b1513333333333333353333333335445fffffffffffffffffffffffff545333333333515b1553b51b1513353
666666666666666666666699433333333333351b531133333333335393333333333335545fffffffffffffffffffffffff533333333331bb4511351b53113333
66666666666667777776666f943333333333bbb515513333333335333335333333335455ffffffffffffffffffffffff5ff5333333333b534353bbb515513333
6666666666666666666666696f43333333331155b13333333333333333533333333335ff5fffffffffffffffffffffffff5333333333353545351155b1333333
66666666666666667777666666f3333333333bbb5311333333333333533333333333545ffffffffffffffffffffffffff54533333333335353533bbb53113333
6666666666666666666666666743333333333515b555333333333333333333333333545f5ffffffffffffffffffffffff553dd333333333333333515b5553333
666666667777666677776777699333333333315b411133333333333333333333333335ff5fffffffffffffffffffffff5ff5333ddddd33333333315b41113333
6666666666666666666666669443333333333bb15533333333333333333333333333545fffffffffffffffffffffffffff5333333355333333333bb155333333
6666777776667777766677669933333333333515b1553333333333333333333333335445fffffffffffffffffffffffff5453ddd3333335333333515b1553333
66666666666666666666666664333333333331bb451135333333333333333333333335545fffffffffffffffffffffffff53333333333333333331bb45113533
6666677777766777777677779493333333333b5343535353533333333333333333335455ffffffffffffffffffffffff5ff5ddd33dd3333335333b5343535353
6666666666666666666666666433333333333535453535353533333333333333333335ff5fffffffffffffffffffffffff535533333333333333353545353535
66666666777766667777667769433333333333535353535353333333333333333333545ffffffffffffffffffffffffff54533dddd3333333333335353535353
66666666666666666666766669433333b3335333533333333333333aa33333333333545f5fffffffffffffffffffffff54533333333333333333533353335333
6666666677776667777777779433333b513339333935333333333a94aa333333333335ff5ffffffffffffffffffffffff5455533333333333333393339353933
666666666666666666666666493333b515133353333333333333a4a43a5433333333545fffffffffffffffffffffffff5f549955333333333333335333333353
66667777766667779766799433333b51b151333333533333333334a4a943333333335445fffffffffffffffffffffffff5f55459533333333333333333533333
6666666666666969777966433333351b53113353933333333333a33434a93333333335545ffffffffffffffffffffffffffff554533333333333335393333353
666667777776f4f94f9494933333bbb5155135333335333333334a354343333333335455fffffffffffffffffffffffffffff545953333333333353333353533
66666666666644444444433333331155b13333333353333333333437a4a33333333335ff5fffffffffffffffffffffffffffff54545333333333333333533333
66666666777733333333333333333bbb53113333533333333333334743a333333333545ffffffffffffffffffffffffffffffff5459533333333333353333333
66667666694353335333333333333515b55533333333533353339436939433333333545f5fffffffffffffffffffffffffffffff5453333333333ddd33333333
7777777794333933393533333333315b41113333333339333935394639433333333335ff5ffffffffffffffffffffffffffffffff54555333333353333533333
66666666493333533333333333333bb1553333333333335333335357349333333333545fffffffffffffffffffffffffffffffff5f549955333333533dd33333
76667994333333333353333333333515b155333333333333335333374399333333335445fffffffffffffffffffffffffffffffff5f554595333333353333353
666666433333335393333333333331bb45113533333333539333333633333533333335545ffffffffffffffffffffffffffffffffffff5545333333333dd3333
77769493333335333335333333333b534353535353333533333533375353535353335455fffffffffffffffffffffffffffffffffffff5459533333353333333
6666433333333333335333333333353545353535353333333353333655353535353335ff5fffffffffffffffffffffffffffffffffffff5454533dddd3333333
77773333333333335333333333333353535353535333333353333333535353535333545ffffffffffffffffffffffffffffffffffffffff54595333333353333
674353335333333333333333b333333333333333b3333333333333333333333333335495ffffffffffffffffffffffffffffffffffffffff545333333333dd33
69933933393533333333333b5133333333333333b1333333333339b4b93333333333354ffffffffffffffffffffffffffffffffffffffffff54555333333333d
9443335333333333333333b515133333333333bb1513333333333494395433333333335495ffffffffffffffffffffffffffffffffffffff5f54995533333333
993333333353333333333b51b15133333333bb11b153333333333494b943333333333395495ffffffffffffffffffffffffffffffffffffff5f5545953333ddd
64333353933333333333351b531133333333115b4315333333339b3434b933333333b33394f5fffffffffffffffffffffffffffffffffffffffff55453333333
94933533333533333333bbb515513333333333b11551333333334b3543b33333333333333549fffffffffffffffffffffffffffffffffffffffff5459533ddd3
643333333353333333331155b133333333333b151133333333333436b49333333333bb333354ffffffffffffffffffffffffffffffffffffffffff5454535533
694333335333333333333bbb531133333333315143133333333333b643b333333333333b3335fffffffffffffffffffffffffffffffffffffffffff5459533dd
666643333333333333333515b555333333333515b555333993339436939433333333533353335495ffffffffffffffffffffffffffffffffffffffff54535353
7777f933333333333333315b411133333333315b411139949933394639433333333339333935354ffffffffffffffffffffffffffffffffffffffffff5454545
666669493333333333333bb15533333333333bb1553394943954535734933333333333533333335495ffffffffffffffffffffffffffffffffffffff5f545454
766666f43333333333333515b155333333333515b155349499433337439933333333333333533395495ffffffffffffffffffffffffffffffffffffff5f5f5f5
6666669943333333333331bb45113533333331bb451193343499333633333533333333539333b33394f5ffffffffffffffffffffffffffffffffffffffffffff
7776666f9433333333333b534353535353333b5343534935434333375353535353333533333533333549ffffffffffffffffffffffffffffffffffffffffffff
666666696f433333333335354535353535333535453534379493333655353535353333333353bb333354ffffffffffffffffffffffffffffffffffffffffffff
7777666666f33333333333535353535353333353535333474393333353535353533333335333333b3335ffffffffffffffffffffffffffffffffffffffffffff
666666666666433333333333333333333333333aa3339436939433333333533353335333533333333333545f5fffffffffffffffffffffffffffffffffffffff
666666667777f933333335553333333333333a94aa33394639433333333339333935393339353333333335ff5fffffffffffffffffffffffffffffffffffffff
666666666666694933333353555333333333a4a43a545357349333333333335333333353333333333333545fffffffffffffffffffffffffffffffffffffffff
66667777766666f43333333535353333333334a4a94333374399333333333333335333333353333333335445ffffffffffffffffffffffffffffffffffffffff
666666666666669943335335333333333333a33434a9333633333533333333539333335393333333333335545fffffffffffffffffffffffffffffffffffffff
666667777776666f943335553333333333334a35434333375353535353333533333535333335333333335455ffffffffffffffffffffffffffffffffffffffff
66666666666666696f4333335533333333333437a4a3333655353535353333333353333333533333333335ff5fffffffffffffffffffffffffffffffffffffff
666666667777666666f33333335333333333334743a33333535353535333333353333333533333333333545fffffffffffffffffffffffffffffffffffffffff
666666666666666667433333b3333333b33339a4339a3ddd3333333aa3335333533333333333333333553455ffffffffffffffffffffffffffffffffffffffff
666666667777677769933333b133333b51333394a339353333533a94aa3339333935333333333333545f4545ffffffffffffffffffffffffffffffffffffffff
6666666666666666944333bb151333b515139a3433a333533dd3a4a43a543353333333333333333355f5545fffffffffffffffffffffffffffffffffffffffff
66667777766677669933bb11b1533b51b1513947a9333333533334a4a943333333533333333333354f5f55ffffffffffffffffffffffffffffffffffffffffff
66666666666666666433115b4315351b53114a379334333333dda33434a9335393333333333333545f5ffffffffff5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5
6666677777767777949333b11551bbb51551943439a3333353334a35434335333335333333333545f5ffffffffff545454545454545454545454545454545454
600000000000006664333b1511331155b1339a9794933dddd3333437a4a33333335333333333445f5fffffffffff454545454545454545454545454545454545
60777700000000776943315143133bbb53119936433333333335334743a3333353333333333355f5ffffffffffff353535353535353535353535353535353535
60b000000000006667433515b5553515b555a437a3943ddd33339436939433333333333333553455ffffff5f544533333333333333333ddd33333ddd33333333
70800000000000776993315b4111315b41113a463a433533335339463943333333333333545f4545fffff5f54453333333333333333335333353353333533333
60c000000000006694433bb155333bb155335337349333533dd35357349333333333333355f5545fffffff544533333333333333333333533dd333533dd33333
70eeeeee0000006699333515b1553515b155533743aa33335333333743993333333333354f5f55fffffff5455333333333333333333333335333333353333333
6000000000000066643331bb451131bb451133373333333333dd333633333533333333545f5fffffffff554533333333333333333333333333dd333333dd3333
777666666666777794933b5343533b534353333653533333533333375353535353333545f5fffffffffff5533333333333333333333333335333333353333333

__gff__
0000000404080808080808080808040000000004040404040404040405050440000000040404040404040000808004400000000101018000040002028000094000000000000000000000000010101010000000000000000002020202001010100000000000000000000000020010101000000000000000000000000009000808
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4c5e6e6e6e6e6e6e6e6e6e6e6e6e6e6e6e6e6e6e5e4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c6e6e6e6e6e6e6e5e4c4c4c4c4c4c4c4c4c4c4c4c4c5e4c4c4c4c6e6e5e5e5e5e5e5e6e6e5e5e6e6e5e4c4c4c4c4c4c4c4c4c6e5e4c5e6e6e5e4c4c5e6e6e6e6e5e4c4c4c4c4c4c4c5e6e6e6e6e6e6e6e6e6e6e5e4c4c4c
5e6f271515151515151515151515160b06064a496d5e5e4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c6f480606060b06066d4c4c4c4c4c4c4c4c4c4c4c4c4c4c5e6e6e6f07066d5e5e6f6d6f07066d6f0b096d5e4c4c4c4c4c4c4c6f066d6e6f07076d6e6e6f060606066d6e6e5e4c5e6e6e6f0a084b084a084b064a066d6e5e4c
5f2703030303030303030303030314160b06585c6c6d5e5e5e4c4c4c5e4c4c5e4c4c4c4c4c4c4c4c4f580b0b060b0b064a5d4c4c4c4c4c4c4c4c4c4c5e4c5e6f060608490b066d6f0b0607090b09090606065d4c4c4c4c4c4c5f0606060707090909070706060907090706066d6e6f09070909075b6b58495b4a5a4806065d5e
5f1803030303033703030303030303172a2b06586c066d5e5e5e4c5e4c4c5e4c4c4c4c4c4c4c4c4c5f4a06060b0606065a5d4c4c4c4c4c4c4c4c4c4c5e5e6f080948095807070b070909070b0627151515151f1f1f1f1f1f1f1f1515151515151515151515151515151515151515151515151515165b085a4b594b58484e5e4c
5f1803030303030303031c1c1c1c1c173a3b060b064a0b6d6e6e6e6e6e5e4c4c4c4c4c4c4c4c4c4c5f5836062a2b49064d4c4c4c4c4c4c4c4c4c4c5e4c6f0808065a4a0707080709070906271504030303032f2f2f2f2f2f2f2f0303030303030303030303030303032919290329190303280303141606085b065b06595d5e4c
5f1828280303392919030303030303170b0b09095c586c0b0b0b0b0b066d5e5e4c4c4c4c5e4c4c4c4c4e4f063a3b594d4c4c4c4c4c4c4c4c4c4c4c5e5f4a080a0a0859090b0b0606062715040303030303032f2f2f2f2f2f2f2f03030303030303030303030303030303030303030303030328280314166b084b4906065d4c4c
5f1803032938032819030303190303141608060a586c065c0b490b4a0b496d5e4c4c4c4c4c5e4c4c4c4c5e4e4e4e4e4c4c4c4c4c4c4c4c4c5e5e5e4c6f580a0a0608070b06060627150403030303032325253f3f3f3f3f3f3f3f2525252525252525252525252525252525252525252525251b030303175b0b5b5a4b486d5e4c
5f242525252503030303030303030303141606090a0b08584a596c5a49586c6d6e6e4c4c4c5e5e4c4c4c4c4c4c4c4c4c4c4c5e4c5e4c5e5e4c4c6e6f0b0a0a080606060606062704030303030323252609095d5e5e4c4c5e5e5f0606066b0b0806086b0a08064b066b4b0606066b06064b06240303030316080b6b5b58485d4c
5f3e3e7c3e081303030319232525030303141608090a0a0658480b0b586c08084a066d4c5e5e4c4c4c4c4c4c4c4c4c5e5e4c4c4c5e4c6e6e6e6f0b080a0a080a0806060627150303033903232526090907085d5e5e4c4c5e5e6f4b06065b6c064b6b5b6c066b5b6c4b6b066b064b064b5b066b2403030317060a5b0b09596d5e
5f063c090a080a181a03032608071303030314160909080606586c08067f06065a6c0b5d5e4c4c4c4c4c4c4c5e5e4c4c5e6e6e5e5e6f49060b0b06060b0608060606062704030303390323260607074a06065d5e4c4c5e5e6f065b6c4b2d06065b5b0706065b6c4b5b5b4b5b6c5b6c6b5b6c5b4b180303031606086b09064b5d
5f06060a07060a181a031708350749130303031416090707070b060b0b06067e0b080b6d4c5e4c5e4c4c4c5e4c6e6e6e6f0b496d6f06586c06062715151515151515150403033938032326060907065906495d5e5e4c5e5f4b6b0b085b6c0627151515151515165b3c066b066b064b5b084b085b180303031706085b49095b5d
5f060809072c0d2e0e0e1e0d354a586c1303030314160607070a0a0a0a2c0a2d3c2d060b5d4c4c4c5e4c4c4c5f0b480b2d065a060606062715150403030303030303030303383803232606060609060608586d5e5e4c5e5f5b4b0b0b2c06273929192903030314165b2d4b6c5b6c5b6b065b6c0a24030303031606085906085d
5f060a082d0a0818191a1706355a6c0906130303031415151515151515163e3e3e3e3e066d6e6e4c4c5e4c4c6f485a6c3c2c0b7f2715150403030303030303290319293839030323260606070907060a0806065d4c4c5e5e4f5b6c4b6b2703390303030303030314165b5b6c6b4b085b08062d0a082403030314160a084b065d
5f06060a3c2d0718031a1706343e3e3e33061303191903030319030303141515151515160b49086d6e6e6e6f3c586c2d062715150403030303030303030303031903190303232526060606090706494a06064d5e4c4c5e5e6f4b065b6c18030323252525251b03031416076b4b5b6c6b064b064b0606240303031416065b4b5d
5f06060a0606061803031706482c2d0b350a08242525252503030303030319030303191416596c0606490b483e3e7c3e270303030303030323252525256a25252525252525260606080607060708485a06065d5e5e4c5e5f065b4b06061803031706074b06241b03031416076b4b075b6c5b6c5a0b4b6b240303031416065b5d
5f0606080a0708181a031706590b093c350707080b060b06130303031903031919190303170b08480b584a586c06271504030303036a2525260b5c4a06586c064906060606060608060607090648590b06496d5e5e4c5e6f4b0b5b6c0618030317066b5b6b4b241b03031416075b6c076b6c4b06065b5b6c240303031706085d
5e4f060606060a180303170606090b0b343e3e3e3e3e330b061303282803030303191a031706065a490b5a6c06270403030323252658480b060658596c0b06065a6c0608080a080a080609080a5a0606485a4d5e5e4c5f6b5b6c064b0618030317065b4b4b5b6b241b0303141609074b066b5b6c4b2c0b060618030317080a5d
4c5e4e4f06080618031a1706060809060808090a090b350b0b06180328280303031903031706480b584906062704033903232606060b5c0b480b060b0b4a060606064a06080a060606070707060b080658065d5e4c5e5f06060b0b5b6c1803030316064b5b6b5b6c241b03031416095b6c5b6c4b5b064b06061803031706085d
4c4c5e5f06060618031a17060906060b0b080708070b35060b0b18030303282803031919170b586c06596c27043939032326064a0b0b596c586c0b0606596c0605065a6c05080606060709060806064a064d5e5e4c5e5e4f064b060606241b030314165b4b5b6c4b4b1803030314160b06064b6b5b6c6b0b0c180303170c085d
5e6f6d6f080606181a0317060b0b070607060708080a3506080b1803030303280303031a17060606062715040303032326060b5c2d3c0b0b0606060606060506050a0808490a06060609070606060b59065d5e5e4c5e5e6f065b6c0b4b06241b030314165b6c065b6c180303030317067e3c5b6c2d3c5b6c0618030317064b5d
5f066b0808060618030303160806070b060606060609350b0b0b24256a25030328030303141515151504030339032326064b0b59060b060606064849064849484908050a596c4806090707060b060606065d5e5e4c5e5f6b0606064b5b064b241b030314164b6b064b2403030303170b067c3e3e3e7c3e062704031a17065b5d
5f065b6c4b0606241b03031916090b07080707080806350b080b06485a4a1303030319290319032903292938032326060b4b0b4b0b060648484958484958595859050a050749596c0706062715151515151f1f1f1f1f1f151515165b06065b6b241b030314165b6c5b6c180303031416080608077d7e06081803031a1706065d
5f06064b5b060806241b030317060b07070607060909060b0b0b0a596c4a06130303030329030303030303032326060b4b4a6b5b6c48495c585948585948490a0805084a075a6c090606270303030303032f2f2f2f2f2f0303031416066b3c2d06241b030314164b064b240303030314160608060808062704030303172a2b5d
5e4f065b6b0a0806061803031706090b07070706060607080b060b0b49586c4a136a252525256a252525252526060b6b4b5a4b0648585958484958596c58594a4b2a2b596c070627151503030323256a253f3f3f3f3f3f251b03031416067c3e0b0618030303175b6b5b4b1803030303141515151515150403030303173a3b5d
4c5e4f065b060a080618030317064b0906080b084b060b06080b0b0a5808485a6c584a0749065a6c06494a0606484b5b5b6c5b6c5859490658596c060a06064a4b3a3b27160627040303030323264a596c5d5e5e5e5e5f06241b030314160608060618030303174b5b4b5b241b0303282803030303030303033903031415165d
4c4c5e4f064b06080618030317065b4b0b0b0b4b5b6c0b0706080b0b0708596c0b0b590b596c0b480648584a0b594a4b4b4b065b4b485c0a0a0848490a4a4b5a5b6c0624141504030303030314165a6c065d5e4c5e5e5f064b2403030314160b080618030303175b4b5b6c6b240303032803032938030303393903232525265d
4c5e5e5f065b6c060618030317090b5b6c4b0b5b6c0b0b060b08080b0b0b0b0b2c0b07070b0708586c5a075a0b49596b5a5b4a065b58596c080658596c5a5b6c06060627030303030303232624262a2b065d5e4c5e5e6f6b4b06240303031416060c18030303170c5b4b065b4b24251b0303280303030329380323260606065d
4c5e6e6f4b0806490618030314160608085b6c090b084b0b060b0806070b0b0b0b080b0b080b0859490b48066b5a065b6c4b5906065b6c060a0706060906060706062704030303030323260709483a3b4d5e4c5e5e5f49066b6c06240303031415150403030317066b5b4b066b4b6b24251b030329293839392326060608065d
5e6f08065b6c08586c180303031416070b08080608065b6c0b06070b0b0b08070b070b0b06074a075a485a07271515151515151516060609080a08060707090707270403032325252526090907584d4e5e4c4c5e5e6f594b066b4a0624030303030303030303174b5b6c5b6b5b5b5b4b062425252525252525260608080a065d
5f08064b066b064a0624030303031416090b07060606060b090b060606060b080a0a08070708586c075807270403030303032929141515151515151515151515150403032326080907090709064d5e5e4c4c4c6e6f4b065b4906584806241b03030303030303176b066b065b064b6b5b6c060606064b06064b4b0608066b6c5d
5e4f065b6c5b48586c0824030303031415151515160609060b0b060b0a060b0b06060b0b09080a0606586c180303030303030303282903030303190303030303030303232606080a0a08064d4e5e5e4c5e5e6f0649064a065a2c4b586c06242525251b1c1c1c175b6c5b6c4b065b5b6c06066b06065b6c4b6b4b4b4b6b6c065d
4c5e4f050649586c08080618030303030303030314160606060b06080a060b0606060b0b06060608060606180303032325252503030303030303030303030303032325264906060806064d5e5e4c4c5e5e5f06485a48586c08065b6c060806080a08181c1c1c172c4b06065b6c5b6c066b065b6c0606066b5b5b5b5b6b6c065d
__sfx__
000100000c3300c1300d3300d1300e3300e1300f3300f130103301133012330133301433015330163301733018330193301a3301b3301c3301d3301e3301f3302033021330223302333024330253302633027330
000100003e750377502a65022650136600b650086500a640096400363006630076200c6100d6101061013610156000b6000c6000d6000e6000f60010600126001560015600126000f6000d600086000760005600
000100003401035010360103701038010390103a0103b0103c0103d0103e0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f0103f010
0008001f0565004350026500335003650033500365003650036500535003650043500365007350036500535003650053500265007350076500465005350046500535004650046500435002650026500365002650
001400002660024610246202463024640246502466024670234003e6003060032600336002f600386002e60011600376002f6002a600396002d6002f6003d60036600396003160030600366002f6002d60027600
0002000c0e550026500d550026500f550026500f550026500f5500365010550036500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001e650326503b6503f6501e650106503d7503b75035750317502b7502975024750227501e7501d5501d5501f5501f550235502055020550314503145033450354503645036450324502a4502345020450
000100000a3500b2500b3500d2500c3500e2500d3500f2500f35011250123501425014350162501735018250193501a2501b3501d2501d3501e3501f350213502235024350263502735028350293502a3502b350
000100000c3200c3200d3200d3200e3200e3200f3200f320103201132012320133201432015320163201732018320193201a3201b3201c3201d3201e3201f3202032021320223202332024320253202632027320
000100003c670256701f6603c6503d6500f74031640366302f630076302d420106200962005620036200762005620086200f62003620016100161003610036100361003620036100261002610026100261001610
000100000010000100301502d1502a150261500010024150231502215022150231500010025150281502c15030150321503415000100001000010000100001000010000100001000010000100001000010000100
__music__
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

