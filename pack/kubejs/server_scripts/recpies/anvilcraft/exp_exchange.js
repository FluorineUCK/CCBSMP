// 经验互换：create:experience_nugget(3 点/个) <-> anvilcraft:exp_gem(50 点/个)

ServerEvents.recipes(event => {

  // ---- 经验粒 x50 -> 经验宝石 x3
  event.custom({
    type: 'anvilcraft:item_compress',
    ingredients: [
      { items: 'create:experience_nugget', count: 50 }
    ],
    results: [
      { id: 'anvilcraft:exp_gem', count: 3 }
    ]
  })

  // ---- 经验宝石 x3 -> 经验粒 x50
  event.custom({
    type: 'anvilcraft:unpack',
    ingredients: [
      { items: 'anvilcraft:exp_gem', count: 3 }
    ],
    results: [
      { id: 'create:experience_nugget', count: 50 }
    ]
  })

  console.info('[exp_exchange] 已注册经验互换：3 exp_gem <-> 50 experience_nugget（各 150 点）')
})
