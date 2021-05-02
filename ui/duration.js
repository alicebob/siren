export function duration(t) {
    t = t.toFixed(0);
    var sec = (t % 60).toFixed(0);
    var min = Math.floor(t / 60);
    if (sec < 10) {
        return min + ":0" + sec;
    }
    return min + ":" + sec;
}
