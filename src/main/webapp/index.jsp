
<%@ page language="java" import="java.util.*" pageEncoding="UTF-8"%>
<%
    String path = request.getContextPath();
    String basePath = request.getScheme()+"://"+request.getServerName()+":"+request.getServerPort()+path+"/";
    String scoketPasePath = "ws://"+request.getServerName()+":"+request.getServerPort()+path+"/video/";
%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
    <meta charset="utf-8">
    <script src="https://cdn.bootcss.com/jquery/3.2.1/jquery.min.js"></script>
    <script>
        var monitor ={
            initSucess:false,
            socket    :null,
            PeerConnection:null,
            pc:null,
            started:false,
            localStream:null,
            remoteVideo:null,
            localVideo:null,
            remoteStream:null,
            scoketPath:null,
            roomId:null,
            userId:null,
            socketSate:false,
            iceServer:{//打洞服务器地址配置
                "iceServers": [{
                    "url": "127.0.0.1"
                }]},
            log:function(msg){
                if(console && console.log){
                    console.log(msg);
                }
            },//初始化一些信息
            initialize:function(scoketPath,localVideoId,remoteVideoId,roomId){
                PeerConnection = window.RTCPeerConnection || window.mozRTCPeerConnection || window.webkitRTCPeerConnection;
                monitor.remoteVideo = $("#"+remoteVideoId);
                monitor.localVideo = $("#"+localVideoId);
                monitor.scoketPath   = scoketPath;
                monitor.roomId = roomId;
                monitor.userId = new Date().getTime();
            },//打开webscoket
            openChannel:function(){
                monitor.socketSate=true;
                monitor.socket = new WebSocket(monitor.scoketPath+monitor.roomId+"/"+monitor.userId);
                monitor.socket.onopen = monitor.onopen;
                monitor.socket.onmessage = monitor.onChannelMessage;
                monitor.socket.onclose = monitor.onChannelClosed;
            },
            onopen:function(onopenCallBack){
                monitor.log("websocket打开");
                monitor.socketSate = true;
                monitor.getUserMedia();
            },
            onChannelClosed:function(){
                monitor.log("websocket关闭");
                monitor.socketSate=false;
                monitor.openChannel();
            },
            onChannelMessage:function(message){
                monitor.log("收到信息 : " + message.data);
                if(message.data=="query-On-line-Yes"){
                    monitor.maybeStart();
                }else if(message.data=="peopleMax"){
                    alert("人数已经超过限制");
                }else if(message.data=="bye"){
                    monitor.onRemoteClose();
                }else if(message.data!="query-On-line-No"){
                    monitor.processSignalingMessage(message.data);//建立视频连接
                }
            },
            getUserMedia:function(){
                monitor.log("获取用户媒体");
                navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia;
                navigator.getUserMedia({
                    "audio" : true,
                    "video" : true
                },monitor.onUserMediaSuccess, monitor.onUserMediaError);
            },
            onUserMediaSuccess:function(stream){
                monitor.log("获取媒体成功");
                monitor.localStream=stream;
                var url = window.URL.createObjectURL(stream);
                monitor.localVideo.attr("src",url);
                monitor.sendMessageByString("query-On-line");
            },
            onUserMediaError:function(){
                monitor.log("获取用户流失败！");
            },
            maybeStart:function(){
                if (!monitor.started) {
                    monitor.createPeerConnection();
                    monitor.pc.addStream(monitor.localStream);
                    monitor.started = true;
                    monitor.doCall();
                }
            },
            createPeerConnection:function(){
                monitor.pc = new PeerConnection(monitor.iceServer);
                monitor.pc.onicecandidate =monitor.onIceCandidate;
                monitor.pc.onconnecting = monitor.onSessionConnecting;
                monitor.pc.onopen = monitor.onSessionOpened;
                monitor.pc.onaddstream = monitor.onRemoteStreamAdded;
                monitor.pc.onremovestream = monitor.onRemoteStreamRemoved;
            },
            onSessionConnecting:function(message){
                monitor.log("开始连接");
            },
            onSessionOpened:function(message){
                monitor.log("连接打开");
            },
            onRemoteStreamAdded:function(event){
                monitor.log("远程视频添加");
                if(monitor.remoteVideo!=null){
                    var url = window.URL.createObjectURL(event.stream);

                    monitor.remoteVideo.attr("src",url);
                    monitor.remoteStream = event.stream;
                    monitor.waitForRemoteVideo();
                }

            },
            waitForRemoteVideo:function(){
                if (monitor.remoteVideo[0].currentTime > 0) { // 判断远程视频长度
                    monitor.transitionToActive();
                } else {
                    setTimeout(monitor.waitForRemoteVideo, 100);
                }
            },
            transitionToActive:function(){
                monitor.log("连接成功！");
                monitor.sendMessageByString("connection_open");
            },
            onRemoteStreamRemoved:function(event){
                monitor.log("远程视频移除");
            },
            onIceCandidate:function(event){
                if (event.candidate) {
                    monitor.sendMessage({
                        type : "candidate",
                        label : event.candidate.sdpMLineIndex,
                        id : event.candidate.sdpMid,
                        candidate : event.candidate.candidate
                    });
                } else {
                    monitor.log("End of candidates.");
                }
            },
            processSignalingMessage:function(message){
                var msg = JSON.parse(message);
                if (msg.type === "offer") {
                    if (!monitor.started)
                        monitor.maybeStart();
                    monitor.pc.setRemoteDescription(new RTCSessionDescription(msg),function(){
                        monitor.doAnswer();
                    },function(){
                    });
                } else if (msg.type === "answer" && monitor.started) {
                    monitor.pc.setRemoteDescription(new RTCSessionDescription(msg));
                } else if (msg.type === "candidate" && monitor.started) {
                    var candidate = new RTCIceCandidate({
                        sdpMLineIndex : msg.label,
                        candidate : msg.candidate
                    });
                    monitor.pc.addIceCandidate(candidate);
                }
            },
            doAnswer:function (){
                monitor.pc.createAnswer(monitor.setLocalAndSendMessage, function(e){
                    monitor.log("创建相应失败"+e);
                });
            },
            doCall:function(){
                monitor.log("开始呼叫");
                monitor.pc.createOffer(monitor.setLocalAndSendMessage,function(){
                });
            },
            setLocalAndSendMessage:function(sessionDescription){
                monitor.pc.setLocalDescription(sessionDescription);
                monitor.sendMessage(sessionDescription);
            },
            sendMessage:function(message){
                var msgJson = JSON.stringify(message);
                monitor.sendMessageByString(msgJson);
            },
            sendMessageByString:function(message){
                monitor.socket.send(message);
                monitor.log("发送信息 : " + message);
            },
            onRemoteClose:function(){
                monitor.started = false;
                monitor.pc.close();
                monitor.sendMessageByString("connection_colse");
            }
        };


    </script>

    <style type="text/css">
        .right{
            height: 80%;
            position:absolute;
            right: 40px;
            top:40px;
            width:180px;
        }
        .remoteAudio{
            margin-top: 20px;
            list-style:outside none none;
            height:150px;
            width: 180px;
            background-color: black;
            border: 1px red solid;
            text-align:center;
        }

        .name{
            position:absolute;
            z-index:99999;
            left:77px;
        }

    </style>
</head>

<body>
<input type="text" id="roomId"/> <input type="button" value="进入房间" onclick="goRoom()"/>
<script type="text/javascript">
    function goRoom(){
        var $roomId = $("#roomId").val();
        if($roomId==""){
            alert("请输入房间号");
        }else{
            monitor.initialize("<%=scoketPasePath%>", "localVideo","remoteAudio", $roomId);
            monitor.openChannel();
        }
    }

</script>

<div>
    <video id="localVideo" autoplay="autoplay"></video>
</div>
<div>
    <video id="remoteAudio" autoplay="autoplay"></video>
</div>

</body>
</html>

