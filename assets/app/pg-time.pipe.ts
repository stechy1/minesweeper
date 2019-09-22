import { Pipe, PipeTransform } from "@angular/core";

@Pipe ({
    name: 'pgtime'
})
export class PgTimePipe implements PipeTransform {

    transform(value: any, ...args): any {
        if (!value) {
            return '?';
        }
        Object.keys(value).forEach((key) => {
            let val: number | string = +value[key];
            if (val < 10) {
                val = `0${val}`;
            }
            value[key] = val;
        });

        const hours = value['hours'] || "00";
        const minutes = value['minutes'] || "00";
        const seconds = value['seconds'] || "00";
        return `${hours}:${minutes}:${seconds}`;
    }
}