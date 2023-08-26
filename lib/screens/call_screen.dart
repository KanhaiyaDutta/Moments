import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:moments/services/signalling_service.dart';

class CallScreen extends StatefulWidget {
  final String callerId, calleeId;
  final dynamic offer;
  const CallScreen({
    super.key,
    required this.callerId,
    required this.calleeId,
    this.offer,
  });

  @override
  State<CallScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<CallScreen> {
  final socket = SignallingService.instance.socket;

  final _localVideoRenderer = RTCVideoRenderer();
  final _remoteVideoRenderer = RTCVideoRenderer();

  MediaStream? _localStream;

  RTCPeerConnection? _peerConnection;

  List<RTCIceCandidate> iceCandidates = [];

  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;

  @override
  void initState() {
    _localVideoRenderer.initialize();
    _remoteVideoRenderer.initialize();

    // setup Peer Connection
    _setupPeerConnection();
    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  _setupPeerConnection() async {
    // create peer connection
    _peerConnection = await createPeerConnection(
      {
        'iceServers': [
          {
            'urls': [
              'stun:stun1.l.google.com:19302',
              'stun:stun2.l.google.com:19302',
            ]
          }
        ]
      },
    );

    // listen for remotePeer mediaTrack event
    _peerConnection!.onTrack = (event) {
      _remoteVideoRenderer.srcObject = event.streams[0];
      setState(() {});
    };

    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    //add mediaTrack to peerConnection
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // set source for local video renderer
    _localVideoRenderer.srcObject = _localStream;
    setState(() {});

    // for Incoming call
    if (widget.offer != null) {
      // listen for remote Icecandidate
      socket!.on("IceCandidate", (data) {
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];

        // add iceCandidate
        _peerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      // set SDP offer as remoteDescription for peerConnection
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(
        widget.offer["sdp"],
        widget.offer["type"],
      ));

      // create SDP answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();

      //set SDP answer as localDescription for peerConnection
      _peerConnection!.setLocalDescription(answer);

      // send sdp answer to remote peer over signalling
      socket!.emit("answerCall", {
        "callerId": widget.callerId,
        "sdpAnswer": answer.toMap(),
      });
    }

    // for outgoing call
    else {
      // listen for local iceCandidate and add it to the list of IceCandidte
      _peerConnection!.onIceCandidate =
          (RTCIceCandidate candidate) => iceCandidates.add(candidate);

      // when call is accepted by remote peer
      socket!.on("callAnswered", (data) async {
        //set SDP answer as remote description for peerConnection
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(
          data["sdpAnswer"]["sdp"],
          data["sdpAnswer"]["type"],
        ));

        // send iceCandidate generated to remote peer over signalling
        for (RTCIceCandidate candidate in iceCandidates) {
          socket!.emit("IceCandidate", {
            "calleeId": widget.calleeId,
            "candidate": {
              "id": candidate.sdpMid,
              "label": candidate.sdpMLineIndex,
              "candidate": candidate.candidate,
            }
          });
        }
      });

      // create SDP offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();

      //set SDP offer as localDescription for peerConnection
      await _peerConnection!.setLocalDescription(offer);

      // send sdp offer to remote peer over signalling
      socket!.emit("makeCall", {
        "callerId": widget.callerId,
        "sdpAnswer": offer.toMap(),
      });
    }
  }

  _leaveCall() {
    Navigator.pop(context);
  }

  _toggleMic() {
    // change status
    isAudioOn = !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleCamera() {
    // change status
    isVideoOn = !isVideoOn;
    // enable or disable video track
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  _switchCamera() {
    // change status
    isFrontCameraSelected = !isFrontCameraSelected;
    // switch camera
    _localStream?.getVideoTracks().forEach((track) {
      track.switchCamera();
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Moments Call'),
      ),
      body: SafeArea(
          child: Column(
        children: [
          Expanded(
              child: Stack(
            children: [
              RTCVideoView(
                _remoteVideoRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: SizedBox(
                  height: 150,
                  width: 120,
                  child: RTCVideoView(
                    _localVideoRenderer,
                    mirror: isFrontCameraSelected,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              )
            ],
          )),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  onPressed: _toggleMic,
                  icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                ),
                IconButton(
                  onPressed: _leaveCall,
                  icon: const Icon(Icons.call_end),
                  iconSize: 30,
                ),
                IconButton(
                    onPressed: _switchCamera,
                    icon: const Icon(Icons.cameraswitch)),
                IconButton(
                  onPressed: _toggleCamera,
                  icon: Icon(isVideoOn ? Icons.videocam : Icons.videocam_off),
                )
              ],
            ),
          )
        ],
      ),
    ),
    );
  }

  @override
  void dispose() {
    _localVideoRenderer.dispose();
    _remoteVideoRenderer.dispose();

    _localStream?.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }
}
