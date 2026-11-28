// ============================================================================
//  任意「有耐久」物品  ->  同一物品 + 无法破坏（minecraft:unbreakable）
//  锻造台：模板 = create:experience_nugget    添加物 = anvilcraft:processor
//          基底 = 待改造的那个物品（附魔 / 自定义名 / 磨损值原样保留）
//  纯 KubeJS，不写 Java、不加数据包
// ============================================================================

const TEMPLATE_ITEM = 'create:experience_nugget' // 模板槽
const ADDITION_ITEM = 'anvilcraft:processor'     // 添加物槽（每次消耗 1 个）
const SHOW_IN_TOOLTIP = true                     // 物品提示里是否显示「无法破坏」一行

// 'all'  = 扫描注册表，自动给所有有耐久的物品生成配方
// 'list' = 只处理下面 ITEM_LIST 里写死的物品
const MODE = 'all'
const ITEM_LIST = [
  // 'minecraft:diamond_pickaxe',
  // 'minecraft:netherite_chestplate',
]

// 不想被改造的物品
const BLACKLIST = [
  // 'minecraft:elytra',
]

ServerEvents.recipes(event => {
  const $BuiltInRegistries = Java.loadClass('net.minecraft.core.registries.BuiltInRegistries')
  const $DataComponents = Java.loadClass('net.minecraft.core.component.DataComponents')

  // ---- 1. 收集目标物品 ----
  let ids = []
  if (MODE === 'list') {
    ids = ITEM_LIST.slice()
  } else {
    let it = $BuiltInRegistries.ITEM.iterator()
    while (it.hasNext()) {
      let item = it.next()
      let comps = item.components()
      if (!comps.has($DataComponents.MAX_DAMAGE)) continue // 没耐久，跳过
      if (comps.has($DataComponents.UNBREAKABLE)) continue // 已经无法破坏，跳过
      ids.push(String($BuiltInRegistries.ITEM.getKey(item)))
    }
  }

  // ---- 2. 每个物品一条锻造配方 ----
  // 原版 smithing_transform 的 assemble 是：
  //   base.transmuteCopy(result.getItem(), result.getCount())  ->  base 的全部非默认组件被搬过去
  //   then applyComponents(result.getComponentsPatch())        ->  再叠加我们写的 unbreakable
  // 所以 result 的 id 必须与 base 相同，附魔/命名/磨损才不会丢。
  // 注意两处 JSON 格式（KJS 走原版 codec，不接受简写的裸字符串）：
  //   template / base / addition 是 Ingredient.CODEC -> 必须写成 {"item":"<id>"} 或 [{"item":"<id>"}]
  //   result 是 ItemStack.STRICT_CODEC -> {"id","count","components"}
  let made = 0
  ids.forEach(id => {
    if (BLACKLIST.includes(id)) return
    event.custom({
      type: 'minecraft:smithing_transform',
      template: { item: TEMPLATE_ITEM },
      base: { item: id },
      addition: { item: ADDITION_ITEM },
      result: {
        id: id,
        count: 1,
        components: {
          'minecraft:unbreakable': { show_in_tooltip: SHOW_IN_TOOLTIP },
        },
      },
    })
    made++
  })

  console.info(`[unbreakable] 共生成 ${made} 条锻造配方（模板 ${TEMPLATE_ITEM} + ${ADDITION_ITEM}）`)
})
