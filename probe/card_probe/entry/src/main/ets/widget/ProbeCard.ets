let storage = new LocalStorage();
storage.setOrCreate('title', '探针卡片');

@Entry(storage)
@Component
struct ProbeCard {
  @LocalStorageProp('title') title: string = '探针卡片';

  build() {
    Stack() {
      Column() {
        Text(this.title).fontSize(16).fontColor('#ffffff')
        Text('blur 对照区').fontSize(12).fontColor('#ffffffd9')
      }
      .width('100%').height('50%')
      .backgroundColor('#ffffff30')
      .backdropBlur(13)
      .borderRadius(22)

      Column() {
        Text('纯色对照区').fontSize(12).fontColor('#ffffff')
      }
      .width('100%').height('50%')
      .backgroundColor('#4a5680')
      .borderRadius(22)
    }
    .width('100%').height('100%')
    .linearGradient({ angle: 150, colors: [['#8e9ff5', 0], ['#c9a7e8', 0.45], ['#f3b6c2', 1]] })
  }
}
