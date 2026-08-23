const catalog = require("../../data/catalog.json");

Page({
  data: { songs: catalog.songs },
  openPractice(e) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({ url: `/pages/practice/practice?id=${id}` });
  },
});
