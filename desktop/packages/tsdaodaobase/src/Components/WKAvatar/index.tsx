import { Channel } from "wukongimjssdk";
import React from "react";
import { Component, CSSProperties } from "react";
import WKApp from "../../App";
import "./index.css"

interface WKAvatarProps {
    channel?: Channel
    src?: string
    style?: CSSProperties
    random?: string
}

export interface WKAvatarState {
    src: string
    loadedErr: boolean
    themeKey: string
    channelKey: string
}

function themeKeyOf() {
    return `${WKApp.config.brandTheme}:${WKApp.config.themeColor}`;
}

function channelKeyOf(props: WKAvatarProps) {
    const { channel, src, random } = props;
    return `${src || ""}|${channel?.channelType || ""}|${channel?.channelID || ""}|${random || ""}`;
}

function resolveSrc(props: WKAvatarProps): string {
    const { channel, src, random } = props;
    let imgSrc = "";
    if (src && src.trim() !== "") {
        imgSrc = src;
    } else if (channel) {
        imgSrc = WKApp.shared.avatarChannel(channel);
    }
    if (!imgSrc) {
        imgSrc = WKApp.config.brandAvatarSrc("defaultPerson");
    }
    if (random && random !== "") {
        imgSrc = `${imgSrc}#${random}`;
    }
    return imgSrc;
}

export default class WKAvatar extends Component<WKAvatarProps, WKAvatarState> {

    constructor(props: any) {
        super(props);
        this.state = {
            src: resolveSrc(props),
            loadedErr: false,
            themeKey: themeKeyOf(),
            channelKey: channelKeyOf(props),
        };
    }

    static getDerivedStateFromProps(props: WKAvatarProps, state: WKAvatarState) {
        const themeKey = themeKeyOf();
        const channelKey = channelKeyOf(props);
        if (themeKey !== state.themeKey || channelKey !== state.channelKey) {
            return {
                src: resolveSrc(props),
                loadedErr: false,
                themeKey,
                channelKey,
            };
        }
        return null;
    }

    handleImgError() {
        this.setState({
            src: WKApp.config.brandAvatarSrc("defaultPerson"),
            loadedErr: true,
        });
    }

    handleLoad() {
        if (!this.state.loadedErr) {
            this.setState({ src: resolveSrc(this.props) });
        }
    }

    render() {
        const { style } = this.props;
        return (
            <img
                key={this.state.themeKey + this.state.channelKey}
                alt=""
                style={style}
                className="wk-avatar"
                src={this.state.src}
                onLoad={this.handleLoad.bind(this)}
                onError={this.handleImgError.bind(this)}
            />
        );
    }
}
