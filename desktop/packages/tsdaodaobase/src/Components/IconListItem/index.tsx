import { Badge } from "@douyinfe/semi-ui";
import React from "react";
import { Component, ReactNode } from "react";
import "./index.css"

export interface IconListItemProps {
    icon: string | ReactNode
    title: string
    backgroudColor?: string
    onClick?: () => void
    badge?: number
}

export default class IconListItem extends Component<IconListItemProps> {


    render(): ReactNode {
        const { icon, title, backgroudColor, onClick, badge } = this.props
        return <div className="wk-iconlistitem" onClick={onClick}>
            <div className="wk-iconlistitem-content">
                <div className="wk-iconlistitem-content-icon" style={backgroudColor ? { backgroundColor: backgroudColor } : undefined}>
                    {typeof icon === "string" ? <img src={icon} alt=""></img> : icon}
                </div>
                <div className="wk-iconlistitem-content-title">
                    {title}
                </div>
                {
                    badge && badge > 0 ? <div className="wk-iconlistitem-content-badge">
                        <Badge count={badge} type="danger"></Badge>
                    </div> : undefined
                }
            </div>
        </div>
    }
}