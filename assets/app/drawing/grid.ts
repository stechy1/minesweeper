import { Drawer } from "./drawer";
import { GridPoint } from "./grid-point";

export class Grid {

    private _points: GridPoint[][];
    private _highlighted: { col: number, row: number } | null;

    constructor(private _drawer: Drawer, private _cols: number, private _rows: number, private _gapSize: number) {
        this._points = [];
        this._prepareGrid();
    }

    _prepareGrid(): void {
        for (let col = 0; col < this._cols; col++) {
            this._points[col] = [];
            for (let row = 0; row < this._rows; row++) {
                this._points[col][row] = new GridPoint(col, row, this._getPoint(col, row));
            }
        }
    }

    _getPoint(col, row): {
        x: number, y: number, topLeft: { x: number, y: number }, topRight: { x: number, y: number }, bottomLeft: { x: number, y: number }, bottomRight: { x: number, y: number }
    } {
        return {
            x: (col * this._gapSize) + this._gapSize / 2,
            y: (row * this._gapSize) + this._gapSize / 2,
            topLeft: {
                x: col * this._gapSize,
                y: row * this._gapSize
            },
            topRight: {
                x: col * this._gapSize + this._gapSize,
                y: row * this._gapSize
            },
            bottomLeft: {
                x: col * this._gapSize,
                y: row * this._gapSize + this._gapSize
            },
            bottomRight: {
                x: col * this._gapSize + this._gapSize,
                y: row * this._gapSize + this._gapSize
            }
        };
    }

    _showHorizontalLines(): void {
        for (let row = 0; row <= this._rows; row++) {
            const pointY = row * this._gapSize;
            this._drawer.drawLine({x: 0, y: pointY}, {x: this.canvasWidth, y: pointY});
            this._drawer.drawText('' + (row + 1), -this._gapSize / 2, pointY + 12);
        }
    }

    _showVerticalLines(): void {
        for (let col = 0; col <= this._cols; col++) {
            const pointX = col * this._gapSize;
            this._drawer.drawLine({x: pointX, y: 0}, {x: pointX, y: this.canvasHeight});
            this._drawer.drawText('' + (col + 1), pointX + this._gapSize / 2, -6);
        }
    }

    _highlight(col: number, row: number): void {
        const point = this._getPoint(col, row);
        this._drawer.push();
        this._drawer.fillStyle = 'rgb(234, 222, 239)';
        this._drawer.fillRectangle(point.topLeft.x + 1, point.topLeft.y + 1, this._gapSize - 3, this._gapSize - 3);
        this._drawer.pop();
    }

    clear(): void {
        for (let col = 0; col < this._cols; col++) {
            for (let row = 0; row < this._rows; row++) {
                const gridPoint = this._points[col][row];
                gridPoint.reset();
            }
        }
    }

    showGrid(): void {
        this._drawer.clear();

        this._drawer.translate(this._gapSize, this._gapSize);

        this._showHorizontalLines();
        this._showVerticalLines();

        if (this._highlighted != null) {
            this._highlight(this._highlighted.col, this._highlighted.row);
        }

        for (let col = 0; col < this._cols; col++) {
            for (let row = 0; row < this._rows; row++) {
                this._points[col][row].draw(this._drawer);
            }
        }
    }

    isMouseInGridmouse(mouse: { x: number, y: number }): boolean {
        const minX = this._gapSize;
        const minY = this._gapSize;
        return mouse.x >= minX
            && mouse.x <= (this.canvasWidth)
            && mouse.y >= minY
            && mouse.y <= (this.canvasHeight);
    }

    mouseToPoint(mouse: { x: number, y: number }): { col: number, row: number } {
        const point = {
            col: Math.floor((mouse.x / this._gapSize)),
            row: Math.floor((mouse.y / this._gapSize))
        };

        point.col -= 1;
        point.row -= 1;

        return point;
    }

    loadPoints(data: any): void {
        this.clear();
        for (let row = 0; row < data.length; row++) {
            const rowArray = data[row]['radek_oblasti'].split('');
            for (let col = 0; col < rowArray.length; col++) {
                const value = rowArray[col];
                this._points[col][row].value = value;
            }
        }
    }

    savePoints(): Array<{ col: number, row: number }> {
        const points = [];
        for (let col = 0; col < this._cols; col++) {
            for (let row = 0; row < this._rows; row++) {
                const gridPoint = this._points[col][row];
                if (gridPoint.value === 1) {
                    points.push({col: gridPoint.col, row: gridPoint.row});
                }
            }
        }

        return points;
    }

    get canvasWidth() {
        return this._rows * this._gapSize + this._gapSize + 1;
    }

    get canvasHeight() {
        return this._cols * this._gapSize + this._gapSize + 1;
    }

    get drawer(): Drawer {
        return this._drawer;
    }

    get points(): GridPoint[][] {
        return this._points;
    }

    set highlighted(point: { col: number, row: number } | null) {
        this._highlighted = point;
    }

}