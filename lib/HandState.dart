enum HandState {
  Tracking,
  Unsure,
  NoData,
  Locking,
  Press,
  Gesture
}

Map<HandState, double> transitionDuration = {
  HandState.NoData: 0.2,
  ///HandState.Tracking: 20,
  HandState.Press: 0.2,
  HandState.Gesture:1.3,
};//seconds
