import { Component, ElementRef, OnDestroy, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute } from "@angular/router";
import { MinesweeperService } from "../minesweeper.service";
import { Subscription } from "rxjs/Subscription";
import { Drawer } from "../drawing/drawer";
import { Grid } from "../drawing/grid";

@Component({
    selector: 'app-game',
    templateUrl: './game.component.html',
    styleUrls: ['./game.component.css']
})
export class GameComponent implements OnInit, OnDestroy {

    private _routeSub: Subscription;
    private _gameDataSub: Subscription;
    private _errorSub: Subscription;

    @ViewChild('game_canvas')
    private _canvas: ElementRef;
    private _grid: Grid;
    private _areaId: number;
    private _minesCount: number;
    private _minesRemaining: number;
    private _dificulty: string;
    private _gameState: number = 0;

    constructor(private _service: MinesweeperService, private _route: ActivatedRoute) {
    }

    _mousePosRelative(event: MouseEvent): { x: number, y: number } {
        const rect = this._canvas.nativeElement.getBoundingClientRect();
        return {x: event.clientX - rect.left, y: event.clientY - rect.top};
    }

    _redrawCanvas(): void {
        this._grid.drawer.push();
        this._grid.showGrid();
        this._grid.drawer.pop();
    }

    _getBadMines(): void {
        this._service.getBadMines(this._areaId)
            .then(value => {
                this._grid.loadBadMines(value);
                this._redrawCanvas();
            });
    }

    ngOnInit(): void {
        const drawer = new Drawer(this._canvas.nativeElement.getContext('2d'));

        this._errorSub = this._service.errorListener().subscribe(err => {
            console.log(err);
        });

        const self = this;

        this._routeSub = this._route.paramMap.subscribe(params => {
            self._areaId = +params.get('id');
            self._service.getAreaInfo(self._areaId)
            .then(info => {
                const sloupcu = info['sloupcu'];
                const radku = info['radku'];
                self._minesCount = info['min'];
                self._dificulty = info['obtiznost'];

                self._grid = new Grid(drawer, sloupcu, radku, 20);
                self._canvas.nativeElement.width = self._grid.canvasWidth;
                self._canvas.nativeElement.height = self._grid.canvasHeight;
                self._redrawCanvas();

                self._gameDataSub = self._service.getGameData(self._areaId).subscribe(data => {
                    console.log(data);
                    self._gameState = data[0]['id_stav'];
                    self._grid.loadPoints(data);
                    self._redrawCanvas();
                    if (self._gameState == 3) {
                        self._getBadMines();
                    }
                });
            });
        });
    }

    ngOnDestroy(): void {
        this._routeSub.unsubscribe();
        this._gameDataSub.unsubscribe();
        this._errorSub.unsubscribe();
    }

    get gameState(): number {
        return this._gameState;
    }

    handleClick(e: MouseEvent): boolean {
        const coord = this._mousePosRelative(e);
        if (this._grid.isMouseInGridmouse(coord)) {
            const point = this._grid.mouseToPoint(coord);
            this._service.markEmpty(this._areaId, point.col + 1, point.row + 1);
        }
        return false;
    }

    handleContextMenu(e: MouseEvent): boolean {
        const coord = this._mousePosRelative(e);
        if (this._grid.isMouseInGridmouse(coord)) {
            const point = this._grid.mouseToPoint(coord);
            this._service.toggleMine(this._areaId, point.col + 1, point.row + 1);
        }
        return false;
    }

    handleMove(e: MouseEvent): void {
        const coord = this._mousePosRelative(e);
        if (this._grid.isMouseInGridmouse(coord)) {
            this._grid.highlighted = this._grid.mouseToPoint(coord);
            this._redrawCanvas();
        }
    }

    handleLeave(): void {
        this._grid.highlighted = null;
        this._redrawCanvas();
    }
}