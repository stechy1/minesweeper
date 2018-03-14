export class Drawer {

    constructor(private _ctx: CanvasRenderingContext2D) {
        this.lineWidth = 1;
        this.strokeStyle = 'white';
        this.fillStyle = 'white';
    }

    drawPoint(x, y) {
        this._ctx.fillRect(x, y, 1, 1);
    }

    drawLine(start: { x: number, y: number }, end: { x: number, y: number }): void {
        this._ctx.beginPath();
        this._ctx.moveTo(start.x, start.y);
        this._ctx.lineTo(end.x, end.y);
        this._ctx.stroke();
        this._ctx.closePath();
    }

    drawRectangle(x: number, y: number, width: number, height: number): void {
        this._ctx.rect(x, y, width, height);
    }

    fillRectangle(x: number, y: number, width: number, height: number): void {
        this._ctx.fillRect(x, y, width, height);
    }

    drawCircle(x: number, y: number, r: number): void {
        this._ctx.beginPath();
        this._ctx.arc(x, y, r, 0, 2 * Math.PI);
        this._ctx.stroke();
    }

    fillCircle(x: number, y: number, r: number): void {
        this._ctx.beginPath();
        this._ctx.arc(x, y, r, 0, 2 * Math.PI);
        this._ctx.stroke();
        this._ctx.fill();
    }

    drawTriangle(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number): void {
        this._ctx.beginPath();
        this._ctx.moveTo(x1, y1);
        this._ctx.lineTo(x2, y2);
        this._ctx.lineTo(x3, y3);
        this._ctx.fill();
        this._ctx.closePath();
    }

    drawArrow(start: { x: number, y: number }, end: { x: number, y: number }, multiplier = 0.5, offset = 10): void {
        this.drawLine(start, end);
        this._ctx.save();
        this.fillStyle = 'black';
        const angle = Math.atan2(start.y - end.y, start.x - end.x);
        this._ctx.translate(end.x, end.y);
        this._ctx.rotate(angle - Math.PI / 2);
        this.drawTriangle(-offset * multiplier, offset, offset * multiplier, offset, 0, -offset / 3);
        this._ctx.restore();
    }

    drawText(text: string, x: number, y: number): void {
        const measure = this._ctx.measureText(text);
        this._ctx.strokeText(text, x - measure.width / 2, y + 3);
    }

    clear(): void {
        this._ctx.clearRect(0, 0, this._ctx.canvas.width, this._ctx.canvas.height);
    }

    push(): void {
        this._ctx.save();
    }

    pop(): void {
        this._ctx.restore();
    }

    translate(x: number, y: number): void {
        this._ctx.translate(x, y);
    }

    set strokeStyle(value: string | CanvasGradient | CanvasPattern) {
        this._ctx.strokeStyle = value;
    }

    set fillStyle(value: string | CanvasGradient | CanvasPattern) {
        this._ctx.fillStyle = value;
    }

    set lineWidth(value: number) {
        this._ctx.lineWidth = value;
    }
}