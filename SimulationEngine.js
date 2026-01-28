const TOWER_TIERS = {
  1: { attackSpeed: 2, range: 1, critChance: 0.2 },
  2: { attackSpeed: 1, range: 1, critChance: 0.2 },
  3: { attackSpeed: 1, range: 0, critChance: 0.2 },
  4: { attackSpeed: 0.5, range: 1, critChance: 0.2 },
  5: { attackSpeed: 2, range: 3, critChance: 0.2 }
};

const MONSTER_TIERS = {
  1: { stepTicks: 4 },
  2: { stepTicks: 1 },
  3: { stepTicks: 5 },
  4: { stepTicks: 1 },
  5: { stepTicks: 3 }
};

const TYPE_CHART = {
  hunter: { magic: 1.5, brute: 0.5, hunter: 1 },
  magic: { brute: 1.5, hunter: 0.5, magic: 1 },
  brute: { hunter: 1.5, magic: 0.5, brute: 1 }
};

function getTypeMultiplier(attackerType, defenderType) {
  if (!attackerType || !defenderType) return 1;
  if (TYPE_CHART[attackerType] && TYPE_CHART[attackerType][defenderType]) {
    return TYPE_CHART[attackerType][defenderType];
  }
  return 1;
}

function createRNG(seed) {
  if (typeof seed === 'string') {
    seed = hashStringToNumber(seed);
  }
  
  let state = seed;
  
  return function() {
    // Mulberry32 algorithm - a fast, high-quality 32-bit PRNG
    state |= 0; // Convert to 32-bit integer
    state = (state + 0x6D2B79F5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296; // Returns 0 to 1
  };
}

function hashStringToNumber(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash);
}

function withinManhattan(x1, y1, x2, y2, range) {
  const manhattanDistance = Math.abs(x1 - x2) + Math.abs(y1 - y2); // Calculate Manhattan distance: sum of horizontal and vertical steps
  return manhattanDistance <= range;
}

function getSurroundingTiles(x, y, rng, width, height) {
  let tiles = [];
  for (let dx = -rng; dx <= rng; dx++) {
    for (let dy = -rng; dy <= rng; dy++) {
      let tx = x + dx, ty = y + dy;
      if (tx >= 0 && tx < width && ty >= 0 && ty < height && !(dx === 0 && dy === 0)) {
        tiles.push([tx, ty]);
      }
    }
  }
  return tiles;
}

class Beast {
  constructor({ id, name, tier, type, level, health, isTower }) {
    this.id = id;
    this.name = name;
    this.tier = tier;
    this.type = type;
    this.level = level;
    this.health = health;
    this.maxHealth = health;
    this.isTower = isTower;
    this.status = { freeze: 0, shield: 0 };
    if (isTower && tier === 1) this.freezePower = 1;
    if (!isTower && tier === 5) this.status.shield = Math.ceil(health * 0.5);
  }
}

class Tower extends Beast {
  constructor(props) {
    super({ ...props, isTower: true });
    this.attackCounter = 0;
    this.critChance = TOWER_TIERS[this.tier]?.critChance ?? 0.2;
    if (typeof props.critChance === 'number') this.critChance = props.critChance;
    this.range = TOWER_TIERS[this.tier]?.range ?? 1;
    this.position = props.position;
  }

  readyToAttack() {
    if (this.tier === 4) return true;
    return this.attackCounter >= (1 / this.getAttackSpeed());
  }

  getAttackSpeed() {
    return TOWER_TIERS[this.tier]?.attackSpeed;
  }
}

class Monster extends Beast {
  constructor(props) {
    super({ ...props, isTower: false });
    this.path = props.path;
    this.pathIndex = 0;
    this.lastTile = null;
    this.alive = true;
    this.split = false;
    this.freezeTicks = 0;
    this.shield = this.status.shield;
    this.spawnTick = props.spawnTick ?? 0;
    if (this.tier === 3 && !props.split) {
      this.health = Math.ceil(this.health / 5);
      this.maxHealth = this.health;
      this.split = true;
    }
  }

  canMove(currentTick, shouldTeleport = false) {
    if (this.tier === 4) {
      return shouldTeleport;
    } else if (this.freezeTicks > 0) {
      return false;
    }
    const tierSteps = MONSTER_TIERS[this.tier]?.stepTicks ?? 1;
    return (currentTick - this.spawnTick) % tierSteps === 0;
  }
}

class GameGrid {
  constructor(width, height, pathTiles, blockedTiles) {
    this.width = width;
    this.height = height;
    this.pathTiles = pathTiles;
    this.blockedTiles = new Set(blockedTiles.map(([x, y]) => `${x},${y}`));
  }

  isPath(x, y) {
    return this.pathTiles.some(([px, py]) => px === x && py === y);
  }
  
  isBlocked(x, y) {
    return this.blockedTiles.has(`${x},${y}`);
  }
}

class SimulationEngine {
  constructor(config) {
    this.config = config;
    this.rng=createRNG(config.seed ?? 12345)
    this.grid = new GameGrid(
      config.grid.width,
      config.grid.height,
      config.grid.pathTiles,
      config.grid.blockedTiles
    );
    this.towers = [];
    this.monsters = [];
    this.monsterQueue = [];
    this.currentTick = 0;
    this.monstersEscaped = 0;
    this.monstersKilled = 0;
    this.log = [];
    this.finished = false;
    this.winner = null;

    this.initTowers(config.defender);
    this.initMonsterQueue(config.attacker);
  }

  getRandomInt(max) {
    return Math.floor(this.rng() * max);
  }
  
  chance(prob) {
    return this.rng() < prob;
  }
  
  shuffle(arr) {
    let a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = this.getRandomInt(i + 1);
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  sortTileKeys(tileKeys) {
    return tileKeys.slice().sort((a, b) => {
      const [ax, ay] = a.split(',').map(Number);
      const [bx, by] = b.split(',').map(Number);
      if (ax !== bx) return ax - bx;
      return ay - by;
    });
  }

  initTowers(defenderSetup) {
    defenderSetup.towers.forEach((towerData, idx) => {
      const tower = new Tower({
        id: `tower_${idx}`,
        name: towerData.name,
        tier: towerData.tier,
        type: towerData.type,
        level: towerData.level,
        health: towerData.health,
        position: towerData.position,
        critChance: towerData.critChance
      });
      this.towers.push(tower);
    });
  }

  initMonsterQueue(attackerSetup) {
    attackerSetup.beasts.forEach((beastData, idx) => {
      if (beastData.tier === 3) {
        this.monsterQueue.push({
          id: `monster_${idx}`,
          name: beastData.name,
          tier: beastData.tier,
          type: beastData.type,
          level: beastData.level,
          health: beastData.health,
          isSwarm: true,
          swarmCount: 4
        });
      } else {
        this.monsterQueue.push({
          id: `monster_${idx}`,
          name: beastData.name,
          tier: beastData.tier,
          type: beastData.type,
          level: beastData.level,
          health: beastData.health,
          isSwarm: false
        });
      }
    });
  }

  spawnMonster() {
    if (this.monsterQueue.length === 0) return;
    
    const data = this.monsterQueue.shift();
    const startTile = this.config.grid.startTile;
    
    if (data.isSwarm) {
      const swarmCount = data.swarmCount || 4;
      const individualHealth = Math.ceil(data.health / 5);
      
      for (let i = 0; i < swarmCount; i++) {
        const monster = new Monster({
          id: `${data.id}_${i}`,
          name: data.name,
          tier: data.tier,
          type: data.type,
          level: data.level,
          health: individualHealth,
          path: [startTile],
          spawnTick: this.currentTick,
          split: true
        });
        
        this.monsters.push(monster);
        
        this.log.push({
          tick: this.currentTick,
          event: 'spawn',
          monster: monster.id,
          monsterName: monster.name,
          monsterTier: monster.tier,
          monsterType: monster.type,
          tile: startTile,
          swarmMember: i + 1,
          swarmTotal: swarmCount
        });
      }
    } else {
      const monster = new Monster({
        ...data,
        path: [startTile],
        spawnTick: this.currentTick
      });
      
      if (monster.tier === 5) {
        monster.shield = Math.ceil(monster.health * 0.5);
      }
      
      this.monsters.push(monster);
      
      this.log.push({
        tick: this.currentTick,
        event: 'spawn',
        monster: monster.id,
        monsterName: monster.name,
        monsterTier: monster.tier,
        monsterType: monster.type,
        tile: startTile
      });
    }
  }

  getAdjacentPathTiles(x, y) {
    const dirs = [
      [0, -1], [0, 1], [-1, 0], [1, 0]
    ];
    let neighbors = [];
    for (const [dx, dy] of dirs) {
      const nx = x + dx, ny = y + dy;
      if (this.grid.isPath(nx, ny) && !this.grid.isBlocked(nx, ny)) {
        neighbors.push([nx, ny]);
      }
    }
    return neighbors;
  }

  moveMonster(monster) {
    if (!monster.alive) return;
    if (monster.freezeTicks > 0) {
      monster.freezeTicks--;
      return;
    }
    if (!monster.canMove(this.currentTick, monster.tier === 4 ? this.chance(0.1) : false)) return;

    const [cx, cy] = monster.path[monster.path.length - 1];
    let neighbors = this.getAdjacentPathTiles(cx, cy);

    if (monster.lastTile) {
      const [lx, ly] = monster.lastTile;
      neighbors = neighbors.filter(([nx, ny]) => !(nx === lx && ny === ly));
      if (neighbors.length === 0) {
        neighbors = [[lx, ly]];
      }
    }

    if (neighbors.length === 0) {
      this.monsterEscaped(monster);
      return;
    }

    let moveTiles = 1;
    if (monster.tier === 4 && this.chance(0.1)) {
      moveTiles = 2;
    }

    for (let step = 0; step < moveTiles; step++) {
      const [currX, currY] = monster.path[monster.path.length - 1];
      let nextNeighbors = this.getAdjacentPathTiles(currX, currY);

      if (monster.lastTile) {
        const [lx, ly] = monster.lastTile;
        nextNeighbors = nextNeighbors.filter(([nx, ny]) => !(nx === lx && ny === ly));
        if (nextNeighbors.length === 0) {
          nextNeighbors = [[lx, ly]];
        }
      }

      if (nextNeighbors.length === 0) {
        this.monsterEscaped(monster);
        return;
      }

      const idx = this.getRandomInt(nextNeighbors.length);
      const [nx, ny] = nextNeighbors[idx];

      monster.lastTile = [currX, currY];
      monster.path.push([nx, ny]);

      this.log.push({
        tick: this.currentTick,
        event: 'move',
        monster: monster.id,
        from: [currX, currY],
        to: [nx, ny]
      });

      if (this.isEndTile(nx, ny)) {
        this.monsterEscaped(monster);
        return;
      }
    }
  }

  isEndTile(x, y) {
    const end = this.config.grid.endTile;
    return end[0] === x && end[1] === y;
  }

  monsterEscaped(monster) {
    monster.alive = false;
    this.monstersEscaped++;
    this.log.push({
      tick: this.currentTick,
      event: 'escaped',
      monster: monster.id,
      monsterName: monster.name
    });
  }

  getMonstersAtTile(x, y) {
    return this.monsters.filter(m => {
      if (!m.alive) return false;
      const pos = m.path[m.path.length - 1];
      return pos[0] === x && pos[1] === y;
    });
  }

  getMonstersInRange(tower) {
    const [tx, ty] = tower.position;
    const rng = tower.range;
    if (rng === 0) return this.monsters.filter(m => m.alive);
    return this.monsters.filter(m => {
      if (!m.alive) return false;
      const pos = m.path[m.path.length - 1];
      return withinManhattan(tx, ty, pos[0], pos[1], rng);
    });
  }

  getTilesWithMonstersInRange(tower) {
    const [tx, ty] = tower.position;
    const rng = tower.range;
    let tilesMap = {};
    this.monsters.forEach(m => {
      if (!m.alive) return;
      const [mx, my] = m.path[m.path.length - 1];
      if (rng === 0 || withinManhattan(tx, ty, mx, my, rng)) {
        const key = `${mx},${my}`;
        if (!tilesMap[key]) tilesMap[key] = [];
        tilesMap[key].push(m);
      }
    });
    return tilesMap;
  }

  applyDamage(monster, damage, isCrit, tower) {
    let shieldAbsorbed = 0;
    if (monster.tier === 5 && monster.shield > 0) {
      if (damage >= monster.shield) {
        shieldAbsorbed = monster.shield;
        damage = 0;
        monster.shield = 0;
      } else {
        shieldAbsorbed = damage;
        monster.shield -= damage;
        damage = 0;
      }
    }
    monster.health -= damage;
    if (monster.health <= 0) {
      monster.alive = false;
      this.monstersKilled++;
      this.log.push({
        tick: this.currentTick,
        event: 'killed',
        monster: monster.id,
        monsterName: monster.name,
        tower: tower.id,
        towerName: tower.name,
        crit: isCrit,
        shieldAbsorbed: shieldAbsorbed
      });
    }
  }

  towerAttack(tower) {
    const isCrit = this.chance(tower.critChance);
    const critMultiplier = isCrit ? 2 : 1;

    if (tower.tier === 1) {
      this.towerTier1Attack(tower, isCrit, critMultiplier);
    } else if (tower.tier === 2) {
      this.towerTier2Attack(tower, isCrit, critMultiplier);
    } else if (tower.tier === 3) {
      this.towerTier3Attack(tower, isCrit, critMultiplier);
    } else if (tower.tier === 4) {
      this.towerTier4Attack(tower, isCrit, critMultiplier);
    } else if (tower.tier === 5) {
      this.towerTier5Attack(tower, isCrit, critMultiplier);
    }
  }

  towerTier1Attack(tower, isCrit, critMultiplier) {
    const tilesMap = this.getTilesWithMonstersInRange(tower);
    const tileKeys = this.sortTileKeys(Object.keys(tilesMap));
    if (tileKeys.length === 0) return;

    const targetKey = tileKeys[this.getRandomInt(tileKeys.length)];
    const monstersOnTile = tilesMap[targetKey];

    let freezeCount = 1;
    if (tower.level >= 30 && tower.level < 60) freezeCount = 2;
    else if (tower.level >= 60 && tower.level < 100) freezeCount = 3;
    else if (tower.level >= 100) freezeCount = monstersOnTile.length;

    const freezeDuration = 1 * critMultiplier;
    const shuffled = this.shuffle(monstersOnTile);

    for (let i = 0; i < Math.min(freezeCount, shuffled.length); i++) {
      const m = shuffled[i];
      if (m.tier === 5) continue;
      const multiplier = getTypeMultiplier(tower.type, m.type);
      const effectiveFreeze = Math.ceil(freezeDuration * multiplier);
      m.freezeTicks += effectiveFreeze;
      this.log.push({
        tick: this.currentTick,
        event: 'freeze',
        tower: tower.id,
        towerName: tower.name,
        monster: m.id,
        monsterName: m.name,
        duration: effectiveFreeze,
        crit: isCrit,
        typeMultiplier: multiplier
      });
    }
  }

  towerTier2Attack(tower, isCrit, critMultiplier) {
    const tilesMap = this.getTilesWithMonstersInRange(tower);
    const tileKeys = this.sortTileKeys(Object.keys(tilesMap));
    if (tileKeys.length === 0) return;

    const targetKey = tileKeys[this.getRandomInt(tileKeys.length)];
    const [tx, ty] = targetKey.split(',').map(Number);
    const damage = Math.ceil((tower.level / 10) * critMultiplier);

    const aoe = getSurroundingTiles(tx, ty, 1, this.grid.width, this.grid.height);
    aoe.push([tx, ty]);

    aoe.forEach(([ax, ay]) => {
      const ms = this.getMonstersAtTile(ax, ay);
      ms.forEach(m => {
        const multiplier = getTypeMultiplier(tower.type, m.type);
        const effectiveDamage = Math.ceil(damage * multiplier);
        this.applyDamage(m, effectiveDamage, isCrit, tower);
        this.log.push({
          tick: this.currentTick,
          event: 'damage',
          tower: tower.id,
          towerName: tower.name,
          monster: m.id,
          monsterName: m.name,
          damage: effectiveDamage,
          crit: isCrit,
          typeMultiplier: multiplier
        });
      });
    });
  }

  towerTier3Attack(tower, isCrit, critMultiplier) {
    const damage = Math.ceil((tower.level / 100) * critMultiplier);
    this.monsters.forEach(m => {
      if (!m.alive) return;
      const multiplier = getTypeMultiplier(tower.type, m.type);
      const effectiveDamage = Math.ceil(damage * multiplier);
      this.applyDamage(m, effectiveDamage, isCrit, tower);
      this.log.push({
        tick: this.currentTick,
        event: 'damage',
        tower: tower.id,
        towerName: tower.name,
        monster: m.id,
        monsterName: m.name,
        damage: effectiveDamage,
        crit: isCrit,
        typeMultiplier: multiplier
      });
    });
  }

  towerTier4Attack(tower, isCrit, critMultiplier) {
    for (let atk = 0; atk < 2; atk++) {
      const tilesMap = this.getTilesWithMonstersInRange(tower);
      const tileKeys = this.sortTileKeys(Object.keys(tilesMap));
      if (tileKeys.length === 0) return;

      let rightmost = null;
      let rightmostX = -Infinity;
      tileKeys.forEach(key => {
        const [x] = key.split(',').map(Number);
        if (x > rightmostX) {
          rightmostX = x;
          rightmost = key;
        }
      });

      const targets = tilesMap[rightmost];
      const target = targets[this.getRandomInt(targets.length)];
      const damage = tower.level * critMultiplier;

      const multiplier = getTypeMultiplier(tower.type, target.type);
      const effectiveDamage = Math.ceil(damage * multiplier);
      this.applyDamage(target, effectiveDamage, isCrit, tower);
      this.log.push({
        tick: this.currentTick,
        event: 'damage',
        tower: tower.id,
        towerName: tower.name,
        monster: target.id,
        monsterName: target.name,
        damage: effectiveDamage,
        crit: isCrit,
        typeMultiplier: multiplier
      });
    }
  }

  towerTier5Attack(tower, isCrit, critMultiplier) {
    const inRange = this.getMonstersInRange(tower);
    if (inRange.length === 0) return;

    let maxHealth = -1;
    let target = null;
    inRange.forEach(m => {
      const totalHP = m.health + (m.shield || 0);
      if (totalHP > maxHealth) {
        maxHealth = totalHP;
        target = m;
      }
    });

    if (!target) return;

    const damage = tower.level * critMultiplier;
    const multiplier = getTypeMultiplier(tower.type, target.type);
    const effectiveDamage = Math.ceil(damage * multiplier);
    this.applyDamage(target, effectiveDamage, isCrit, tower);
    this.log.push({
      tick: this.currentTick,
      event: 'damage',
      tower: tower.id,
      towerName: tower.name,
      monster: target.id,
      monsterName: target.name,
      damage: effectiveDamage,
      crit: isCrit,
      typeMultiplier: multiplier
    });
  }

  processTowerAttacks() {
    this.towers.forEach(tower => {
      if (tower.tier === 4) {
        this.towerAttack(tower);
      } else {
        tower.attackCounter++;
        const attackSpeed = tower.getAttackSpeed();
        if (tower.attackCounter >= attackSpeed) {
          tower.attackCounter = 0;
          this.towerAttack(tower);
        }
      }
    });
  }

  processMonsterMovement() {
    this.monsters.forEach(monster => {
      if (monster.alive) {
        this.moveMonster(monster);
      }
    });
  }

  cleanupDeadMonsters() {
    this.monsters = this.monsters.filter(m => m.alive);
  }

  checkWinCondition() {
    const allSpawned = this.monsterQueue.length === 0;
    const allDead = this.monsters.every(m => !m.alive);

    if (allSpawned && allDead) {
      this.finished = true;
      this.determineWinner();
      return true;
    }
    return false;
  }

  determineWinner() {
    const defenderScore = this.monstersKilled;
    const attackerScore = this.monstersEscaped;

    if (defenderScore > attackerScore) {
      this.winner = 'defender';
    } else if (attackerScore > defenderScore) {
      this.winner = 'attacker';
    } else {
      this.winner = 'draw';
    }

    this.log.push({
      tick: this.currentTick,
      event: 'game_end',
      winner: this.winner,
      monstersKilled: this.monstersKilled,
      monstersEscaped: this.monstersEscaped
    });
  }

  tick() {
    if (this.finished) return;
    this.currentTick++;
    this.spawnMonster();
    this.processTowerAttacks();
    this.processMonsterMovement();
    this.cleanupDeadMonsters();
    this.checkWinCondition();
  }

  run(maxTicks = 1000) {
    while (!this.finished && this.currentTick < maxTicks) {
      this.tick();
    }
    if (!this.finished) {
      this.finished = true;
      this.determineWinner();
    }
    return this.getResult();
  }

  step() {
    if (!this.finished) {
      this.tick();
    }
    return this.getState();
  }

  getState() {
    return {
      tick: this.currentTick,
      finished: this.finished,
      winner: this.winner,
      towers: this.towers.map(t => ({
        id: t.id,
        name: t.name,
        tier: t.tier,
        type: t.type,
        level: t.level,
        position: t.position,
        health: t.health,
        range: t.range
      })),
      monsters: this.monsters.map(m => ({
        id: m.id,
        name: m.name,
        tier: m.tier,
        type: m.type,
        level: m.level,
        health: m.health,
        maxHealth: m.maxHealth,
        shield: m.shield || 0,
        position: m.path[m.path.length - 1],
        alive: m.alive,
        freezeTicks: m.freezeTicks
      })),
      monsterQueueLength: this.monsterQueue.length,
      monstersKilled: this.monstersKilled,
      monstersEscaped: this.monstersEscaped
    };
  }

  getResult() {
    return {
      winner: this.winner,
      totalTicks: this.currentTick,
      monstersKilled: this.monstersKilled,
      monstersEscaped: this.monstersEscaped,
      finalState: this.getState(),
      log: this.log
    };
  }

  getLog() {
    return this.log;
  }

  reset() {
    this.rng = createRNG(this.config.seed ?? 12345);
    this.towers = [];
    this.monsters = [];
    this.monsterQueue = [];
    this.currentTick = 0;
    this.monstersEscaped = 0;
    this.monstersKilled = 0;
    this.log = [];
    this.finished = false;
    this.winner = null;

    this.initTowers(this.config.defender);
    this.initMonsterQueue(this.config.attacker);
  }
}

export {
  SimulationEngine,
  Tower,
  Monster,
  Beast,
  GameGrid,
  TOWER_TIERS,
  MONSTER_TIERS,
  TYPE_CHART,
  getTypeMultiplier
};