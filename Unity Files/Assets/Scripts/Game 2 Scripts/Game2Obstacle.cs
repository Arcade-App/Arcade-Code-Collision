using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Game2Obstacle : MonoBehaviour
{
    float speed = 1f;


    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void FixedUpdate()
    {
        transform.Translate(Vector3.left * speed * Time.fixedDeltaTime);
        if (transform.position.x <= -12f)
        {
            transform.position = new Vector3(transform.position.x + 23f, transform.position.y, transform.position.z);
        }
    }
}
