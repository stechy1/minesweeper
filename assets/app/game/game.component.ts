import {Component, ElementRef, OnDestroy, OnInit, ViewChild} from '@angular/core';
import {ActivatedRoute} from "@angular/router";
import {MinesweeperService} from "../minesweeper.service";
import {Subscription} from "rxjs/Subscription";
import {Drawer} from "../drawing/drawer";
import {Grid} from "../drawing/grid";

@Component({
  selector: 'app-game',
  templateUrl: './game.component.html',
  styleUrls: ['./game.component.css']
})
export class GameComponent implements OnInit, OnDestroy {

  private _routeSub: Subscription;
  private _gameDataSub: Subscription;

  @ViewChild('game_canvas')
  private _canvas: ElementRef;
  private _grid: Grid;
  private _areaId;

  constructor(private _service: MinesweeperService, private _route: ActivatedRoute) {}

  _mousePosRelative(event: MouseEvent): { x: number, y: number } {
    const rect = this._canvas.nativeElement.getBoundingClientRect();
    return { x: event.clientX - rect.left, y: event.clientY - rect.top };
  }

  _redrawCanvas(): void {
    this._grid.drawer.push();
    this._grid.showGrid();
    this._grid.drawer.pop();
  }

  ngOnInit(): void {
    const drawer = new Drawer(this._canvas.nativeElement.getContext('2d'));

    this._routeSub = this._route.paramMap.subscribe(params => {
      this._areaId = +params.get('id');
      this._service.getAreaInfo(this._areaId)
        .then(info => {
          const sloupcu = info['sloupcu'];
          const radku = info['radku'];
          const min = info['min'];
          const obtiznost = info['obtiznost'];

          this._grid = new Grid(drawer, sloupcu, radku, 20);
          this._canvas.nativeElement.width = this._grid.canvasWidth;
          this._canvas.nativeElement.height = this._grid.canvasHeight;
          this._redrawCanvas();

          this._gameDataSub = this._service.getGameData(this._areaId).subscribe(data => {
            console.log(data);
          });
        });
    });
  }

  ngOnDestroy(): void {
    this._routeSub.unsubscribe();
    this._gameDataSub.unsubscribe();
  }

  handleClick(e: MouseEvent): boolean {
    const coord = this._mousePosRelative(e);
    if (this._grid.isMouseInGridmouse(coord)) {
      const point = this._grid.mouseToPoint(coord);
      this._service.markEmpty(this._areaId, point.col, point.row);
    }
    return false;
  }

  handleContextMenu(e: MouseEvent): boolean {
    console.log(e);
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