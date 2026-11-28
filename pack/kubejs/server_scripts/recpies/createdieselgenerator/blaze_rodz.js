// Create Diesel Generators 1.3.16: use two blaze powder instead of four.
ServerEvents.recipes(event=> {
  event.remove({ id:'createdieselgenerators:compression_molding/blaze_rod' }),
  event.custom({
    type: 'createdieselgenerators:compression_molding',
    ingredients: [
      { item: 'minecraft:blaze_powder' },
      { item: 'minecraft:blaze_powder' }
    ],
    mold: 'createdieselgenerators:lines',
    heat_requirement: 'heated',
    results: [{ id: 'minecraft:blaze_rod', count: 1 }]
  }).id('createdieselgenerators:compression_molding/blaze_rod')
})
